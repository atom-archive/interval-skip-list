{clone, include, first, last, union, intersection} = require 'underscore'

remove = (array, element) ->
  index = array.indexOf(element)
  array.splice(index, 1) unless index is -1

DefaultComparator = (a, b) ->
  if a < b
    -1
  else if a > b
    1
  else
    0

module.exports =
class IntervalSkipList
  maxHeight: 8
  probability: .25

  constructor: (params) ->
    {@compare, minIndex, maxIndex} = params if params?
    @compare ?= DefaultComparator
    minIndex ?= -Infinity
    maxIndex ?= Infinity

    @head = new Node(@maxHeight, minIndex)
    @tail = new Node(@maxHeight, maxIndex)
    @head.next[i] = @tail for i in [0...@maxHeight]
    @intervalsByMarker = {}

  # Public: Returns an array of markers for intervals that contain all the given
  # search indices, inclusive of their endpoints.
  findContaining: (searchIndices...) ->
    if searchIndices.length > 1
      searchIndices = @sortIndices(searchIndices)
      return intersection(@findContaining(first(searchIndices)), @findContaining(last(searchIndices)))

    searchIndex = searchIndices[0]
    markers = []
    node = @head
    for i in [@maxHeight - 1..1]
      # Move forward as far as possible while keeping the node's index less
      # than the index for which we're searching.
      while @compare(node.next[i].index, searchIndex) < 0
        node = node.next[i]
      # When the next node's index would be greater than the search index, drop
      # down a level, recording forward markers at the current level since their
      # intervals necessarily contain the search index.
      markers.push(node.markers[i]...)

    # Scan to the node preceding the search index at level 0
    while @compare(node.next[0].index, searchIndex) < 0
      node = node.next[0]
    markers.push(node.markers[0]...)

    # Scan to the next node, which is >= the search index. If it is equal to the
    # search index, we can add any markers starting here to the set of
    # containing markers
    node = node.next[0]
    if @compare(node.index, searchIndex) is 0
      markers.concat(node.startingMarkers)
    else
      markers

  # Public: Returns an array of markers for intervals that intersect the given
  # search indices.
  findIntersecting: (searchIndices...) ->
    union(searchIndices.map((searchIndex) => @findContaining(searchIndex))...)

  # Public: Returns an array of markers for intervals that start at the given
  # search index.
  findStartingAt: (searchIndex) ->
    node = @findClosestNode(searchIndex)
    if @compare(node.index, searchIndex) is 0
      node.startingMarkers
    else
      []

  # Public: Returns an array of markers for intervals that end at the given
  # search index.
  findEndingAt: (searchIndex) ->
    node = @findClosestNode(searchIndex)
    if @compare(node.index, searchIndex) is 0
      node.endingMarkers
    else
      []

  # Public: Returns an array of markers for intervals that start within the
  # given index range, inclusive.
  findStartingIn: (searchStartIndex, searchEndIndex) ->
    markers = []
    node = @findClosestNode(searchStartIndex)
    while @compare(node.index, searchEndIndex) <= 0
      markers.push(node.startingMarkers...)
      node = node.next[0]
    markers

  # Public: Returns an array of markers for intervals that start within the
  # given index range, inclusive.
  findEndingIn: (searchStartIndex, searchEndIndex) ->
    markers = []
    node = @findClosestNode(searchStartIndex)
    while @compare(node.index, searchEndIndex) <= 0
      markers.push(node.endingMarkers...)
      node = node.next[0]
    markers

  # Public: Insert an interval identified by marker that spans inclusively
  # the given start and end indices.
  #
  # * marker: Identifies the interval. Must be a string or a number.
  #
  # Throws an exception if the marker already exists in the list. Use ::update
  # instead if you want to update an existing marker.
  insert: (marker, startIndex, endIndex) ->
    if @intervalsByMarker[marker]?
      throw new Error("Interval for #{marker} already exists.")
    startNode = @insertNode(startIndex)
    endNode = @insertNode(endIndex)
    @placeMarker(marker, startNode, endNode)
    @intervalsByMarker[marker] = [startIndex, endIndex]

  # Public: Remove an interval by its id. Does nothing if the interval does not
  # exist.
  remove: (marker) ->
    return unless interval = @intervalsByMarker[marker]
    [startIndex, endIndex] = interval
    delete @intervalsByMarker[marker]
    startNode = @findClosestNode(startIndex)
    endNode = @findClosestNode(endIndex)
    @removeMarker(marker, startNode, endNode)

    # Nodes may serve as end-points for multiple intervals, so only remove a
    # node if its endpointMarkers set is empty
    @removeNode(startIndex) if startNode.endpointMarkers.length is 0
    @removeNode(endIndex) if endNode.endpointMarkers.length is 0

  # Public: Removes the interval for the given marker if one exists, then
  # inserts the a new interval for the marker based on startIndex and endIndex.
  update: (marker, startIndex, endIndex) ->
    @remove(marker)
    @insert(marker, startIndex, endIndex)

  # Private: Find or insert a node for the given index. If a node is inserted,
  # update existing markers to preserve the invariant that they follow the
  # shortest possible path between their start and end nodes.
  insertNode: (index) ->
    update = @buildUpdateArray()
    closestNode = @findClosestNode(index, update)
    if @compare(closestNode.index, index) > 0
      newNode = new Node(@getRandomNodeHeight(), index)
      for i in [0...newNode.height]
        prevNode = update[i]
        newNode.next[i] = prevNode.next[i]
        prevNode.next[i] = newNode
      @adjustMarkersOnInsert(newNode, update)
      newNode
    else
      closestNode

  # Private: Ensures that all markers leading into and out of the given node
  # are following the highest possible paths to their destination. Some may need
  # to be "promoted" to a higher level now that this node exists.
  adjustMarkersOnInsert: (node, updated) ->
    # Phase 1: Add markers leading out of the inserted node at the highest
    # possible level
    promoted = []
    newPromoted = []

    for i in [0...(node.height - 1)]
      for marker in clone(updated[i].markers[i])
        [startIndex, endIndex] = @intervalsByMarker[marker]
        if @compare(node.next[i + 1].index, endIndex) <= 0
          @removeMarkerOnPath(marker, node.next[i], node.next[i + 1], i)
          newPromoted.push(marker)
        else
          node.addMarkerAtLevel(marker, i)

      for marker in clone(promoted)
        [startIndex, endIndex] = @intervalsByMarker[marker]
        if @compare(node.next[i + 1].index, endIndex) <= 0
          @removeMarkerOnPath(marker, node.next[i], node.next[i + 1], i)
        else
          node.addMarkerAtLevel(marker, i)
          remove(promoted, marker)

      promoted = promoted.concat(newPromoted)
      newPromoted.length = 0

    node.addMarkersAtLevel(updated[i].markers[i].concat(promoted), i)

    # Phase 2: Push markers leading into the inserted node higher, but no higher
    # than the height of the node
    promoted.length = 0
    newPromoted.length = 0
    for i in [0...node.height - 1]
      for marker in clone(updated[i].markers[i])
        [startIndex, endIndex] = @intervalsByMarker[marker]
        if @compare(startIndex, updated[i + 1].index) <= 0
          newPromoted.push(marker)
          @removeMarkerOnPath(marker, updated[i + 1], node, i)

      for marker in clone(promoted)
        [startIndex, endIndex] = @intervalsByMarker[marker]
        if @compare(startIndex, updated[i + 1].index) <= 0
          @removeMarkerOnPath(marker, updated[i + 1], node, i)
        else
          updated[i].addMarkerAtLevel(marker, i)
          remove(promoted, marker)

      promoted = promoted.concat(newPromoted)
      newPromoted.length = 0
    updated[i].addMarkersAtLevel(promoted, i)

  # Private: Removes the node at the given index, then adjusts markers downward
  removeNode: (index) ->
    update = @buildUpdateArray()
    node = @findClosestNode(index, update)
    if @compare(node.index, index) is 0
      @adjustMarkersOnRemove(node, update)
      for i in [0...node.height]
        update[i].next[i] = node.next[i]

  # Private: Adjusts the height of markers that formerly traveled through the
  # removed node. They may now need to follow a lower path in order to avoid
  # overshooting their interval.
  adjustMarkersOnRemove: (node, updated) ->
    demoted = []
    newDemoted = []

    # Phase 1: Lower markers on edges to the left of node if needed
    for i in [node.height - 1..0]
      for marker in clone(updated[i].markers[i])
        [startIndex, endIndex] = @intervalsByMarker[marker]
        if @compare(node.next[i].index, endIndex) > 0
          newDemoted.push(marker)
          updated[i].removeMarkerAtLevel(marker, i)

      for marker in clone(demoted)
        @placeMarkerOnPath(marker, updated[i + 1], updated[i], i)
        [startIndex, endIndex] = @intervalsByMarker[marker]
        if @compare(node.next[i].index, endIndex) <= 0
          updated[i].addMarkerAtLevel(marker, i)
          remove(demoted, marker)

      demoted.push(newDemoted...)
      newDemoted.length = 0

    # Phase 2: Lower markers on edges to the right of node if needed
    demoted.length = 0
    newDemoted.length = 0
    for i in [node.height - 1..0]
      for marker in node.markers[i]
        [startIndex, endIndex] = @intervalsByMarker[marker]
        if @compare(updated[i].index, startIndex) < 0
          newDemoted.push(marker)

      for marker in clone(demoted)
        @placeMarkerOnPath(marker, node.next[i], node.next[i + 1], i)
        [startIndex, endIndex] = @intervalsByMarker[marker]
        if @compare(updated[i].index, startIndex) >= 0
          remove(demoted, marker)

      demoted.push(newDemoted...)
      newDemoted.length = 0

  # Private: Place the given marker on the highest possible path between two
  # nodes. It will follow a stair-step pattern, with a flat or ascending portion
  # followed by a flat or descending section.
  placeMarker: (marker, startNode, endNode) ->
    startNode.addStartingMarker(marker)
    endNode.addEndingMarker(marker)

    startIndex = startNode.index
    endIndex = endNode.index
    node = startNode
    i = 0

    # Mark non-descending path
    while @compare(node.next[i].index, endIndex) <= 0
      i++ while i < node.height - 1 and @compare(node.next[i + 1].index, endIndex) <= 0
      node.addMarkerAtLevel(marker, i)
      node = node.next[i]

    # Mark non-ascending path
    while node isnt endNode
      i-- while i > 0 and @compare(node.next[i].index, endIndex) > 0
      debugger unless node?
      node.addMarkerAtLevel(marker, i)
      node = node.next[i]

  # Private: Removet the given marker from the stairstep-shaped path between the
  # startNode and endNode.
  removeMarker: (marker, startNode, endNode) ->
    startNode.removeStartingMarker(marker)
    endNode.removeEndingMarker(marker)

    startIndex = startNode.index
    endIndex = endNode.index
    node = startNode
    i = 0

    # Unmark non-descending path
    while @compare(node.next[i].index, endIndex) <= 0
      i++ while i < node.height - 1 and @compare(node.next[i + 1].index, endIndex) <= 0
      node.removeMarkerAtLevel(marker, i)
      node = node.next[i]

    # Unmark non-ascending path
    while node isnt endNode
      i-- while i > 0 and @compare(node.next[i].index, endIndex) > 0
      node.removeMarkerAtLevel(marker, i)
      node = node.next[i]

  # Private: Remove marker on all links between startNode and endNode at the
  # given level
  removeMarkerOnPath: (marker, startNode, endNode, level) ->
    node = startNode
    while node isnt endNode
      node.removeMarkerAtLevel(marker, level)
      node = node.next[level]

  # Private: Place marker on all links between startNode and endNode at the
  # given level
  placeMarkerOnPath: (marker, startNode, endNode, level) ->
    node = startNode
    while node isnt endNode
      node.addMarkerAtLevel(marker, level)
      node = node.next[level]

  # Private
  buildUpdateArray: ->
    path = new Array(@maxHeight)
    path[i] = @head for i in [0...@maxHeight]
    path

  # Private: Searches the skiplist in a stairstep descent, following the highest
  # path that doesn't overshoot the index.
  #
  # * next
  #   An array that will be populated with the last node visited at every level
  #
  # Returns the leftmost node whose index is >= the given index
  findClosestNode: (index, update) ->
    currentNode = @head
    for i in [@maxHeight - 1..0]
      # Move forward as far as possible while keeping the currentNode's index less
      # than the index being inserted.
      while @compare(currentNode.next[i].index, index) < 0
        currentNode = currentNode.next[i]
      # When the next node's index would be bigger than the index being inserted,
      # record the last node visited at the current level and drop to the next level.
      update?[i] = currentNode
    currentNode.next[0]

  sortIndices: (indices) ->
    clone(indices).sort (a, b) => @compare(a, b)

  # Private: Returns a height between 1 and maxHeight (inclusive). Taller heights
  # are logarithmically less probable than shorter heights because each increase
  # in height requires us to win a coin toss weighted by @probability.
  getRandomNodeHeight: ->
    height = 1
    height++ while height < @maxHeight and Math.random() < @probability
    height

  # Public: Test-only method to verify that all markers are following maximal paths
  # between the start and end indices of their interval.
  verifyMarkerInvariant: ->
    for marker, [startIndex, endIndex] of @intervalsByMarker
      node = @findClosestNode(startIndex)
      unless @compare(node.index, startIndex) is 0
        throw new Error("Could not find node for marker #{marker} with start index #{startIndex}")
      node.verifyMarkerInvariant(marker, endIndex, @compare)

class Node
  constructor: (@height, @index) ->
    @next = new Array(@height)
    @markers = new Array(@height)
    @markers[i] = [] for i in [0...@height]
    @endpointMarkers = []
    @startingMarkers = []
    @endingMarkers = []

  addStartingMarker: (marker) ->
    @startingMarkers.push(marker)
    @endpointMarkers.push(marker)

  removeStartingMarker: (marker) ->
    remove(@startingMarkers, marker)
    remove(@endpointMarkers, marker)

  addEndingMarker: (marker) ->
    @endingMarkers.push(marker)
    @endpointMarkers.push(marker)

  removeEndingMarker: (marker) ->
    remove(@endingMarkers, marker)
    remove(@endpointMarkers, marker)

  removeMarkerAtLevel: (marker, level) ->
    remove(@markers[level], marker)

  addMarkerAtLevel: (marker, level) ->
    @markers[level].push(marker)

  addMarkersAtLevel: (markers, level) ->
    @addMarkerAtLevel(marker, level) for marker in markers

  markersAboveLevel: (level) ->
    flatten(@markers[level...@height])

  verifyMarkerInvariant: (marker, endIndex, compare) ->
    return if compare(@index, endIndex) is 0
    for i in [@height - 1..0]
      nextIndex = @next[i].index
      if compare(nextIndex, endIndex) <= 0
        unless include(@markers[i], marker)
          throw new Error("Node at #{@index} should have marker #{marker} at level #{i} pointer to node at #{nextIndex} <= #{endIndex}")
        @verifyNotMarkedBelowLevel(marker, i, nextIndex, compare) if i > 0
        @next[i].verifyMarkerInvariant(marker, endIndex, compare)
        return
    throw new Error("Node at #{@index} should have marker #{marker} on some forward pointer to an index <= #{endIndex}, but it doesn't")

  verifyNotMarkedBelowLevel: (marker, level, untilIndex, compare) ->
    for i in [level - 1..0]
      if include(@markers[i], marker)
        throw new Error("Node at #{@index} should not have marker #{marker} at level #{i} pointer to node at #{@next[i].index}")

    if compare(@next[0].index, untilIndex) < 0
      @next[0].verifyNotMarkedBelowLevel(marker, level, untilIndex, compare)
