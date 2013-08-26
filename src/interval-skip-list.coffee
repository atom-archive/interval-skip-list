{clone, include} = require 'underscore'

remove = (array, element) ->
  index = array.indexOf(element)
  array.splice(index, 1) unless index is -1

module.exports =
class IntervalSkipList
  maxHeight: 8
  probability: .25

  constructor: ->
    @head = new Node(@maxHeight, -Infinity)
    @tail = new Node(@maxHeight, Infinity)
    @head.next[i] = @tail for i in [0...@maxHeight]
    @intervalsByMarker = {}

  # Public: Insert an interval identified by marker that spans inclusively
  # the given start and end indices.
  #
  # * marker: Identifies the interval. Must be a string or a number.
  insert: (marker, startIndex, endIndex) ->
    startNode = @insertIndex(startIndex)
    endNode = @insertIndex(endIndex)
    @placeMarker(marker, startNode, endNode)

  # Private: Find or insert a node for the given index. If a node is inserted,
  # update existing markers to preserve the invariant that they follow the
  # shortest possible path between their start and end nodes.
  insertIndex: (index) ->
    update = @buildUpdateArray()
    closestNode = @findClosestNode(index, update)
    if closestNode.index > index
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
        [start, end] = @intervalsByMarker[marker]
        if node.next[i + 1].index <= end
          @removeMarkerOnPath(marker, node.next[i], node.next[i + 1], i)
          newPromoted.push(marker)
        else
          node.addMarkerAtLevel(marker, i)

      for marker in clone(promoted)
        [start, end] = @intervalsByMarker[marker]
        if node.next[i + 1].index <= end
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
        [start, end] = @intervalsByMarker[marker]
        if start <= updated[i + 1].index
          newPromoted.push(marker)
          @removeMarkerOnPath(marker, updated[i + 1], node, i)

      for marker in clone(promoted)
        [start, end] = @intervalsByMarker[marker]
        if start <= updated[i + 1].index
          @removeMarkerOnPath(marker, updated[i + 1], node, i)
        else
          updated[i].addMarkerAtLevel(marker, i)
          remove(promoted, marker)

      promoted = promoted.concat(newPromoted)
      newPromoted.length = 0
    updated[i].addMarkersAtLevel(promoted, i)

  # Private: Place the given marker on the highest possible path between two
  # nodes. It will follow a stair-step pattern, with a flat or ascending portion
  # followed by a flat or descending section.
  placeMarker: (marker, startNode, endNode) ->
    startIndex = startNode.index
    endIndex = endNode.index
    node = startNode
    i = 0

    # Mark non-descending path
    while node.next[i].index <= endIndex
      i++ while i < node.height - 1 and node.next[i + 1].index <= endIndex
      node.addMarkerAtLevel(marker, i)
      node = node.next[i]

    # Mark non-ascending path
    while node isnt endNode
      i-- while i > 0 and node.next[i].index > endIndex
      node.addMarkerAtLevel(marker, i)
      node = node.next[i]

    @intervalsByMarker[marker] = [startIndex, endIndex]

  # Private: Remove marker on all links between startNode and endNode at the
  # given level
  removeMarkerOnPath: (marker, startNode, endNode, level) ->
    node = startNode
    while node isnt endNode
      node.removeMarkerAtLevel(marker, level)
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
      while currentNode.next[i].index < index
        currentNode = currentNode.next[i]
      # When the next node's index would be bigger than the index being inserted,
      # record the last node visited at the current level and drop to the next level.
      update?[i] = currentNode
    currentNode.next[0]

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
      node.verifyMarkerInvariant(marker, endIndex)

class Node
  constructor: (@height, @index) ->
    @next = new Array(@height)
    @markers = new Array(@height)
    @markers[i] = [] for i in [0...@height]

  removeMarkerAtLevel: (marker, level) ->
    remove(@markers[level], marker)

  addMarkerAtLevel: (marker, level) ->
    @markers[level].push(marker)

  addMarkersAtLevel: (markers, level) ->
    @addMarkerAtLevel(marker, level) for marker in markers

  verifyMarkerInvariant: (marker, endIndex) ->
    return if @index is endIndex
    for i in [@height - 1..0]
      nextIndex = @next[i].index
      if nextIndex <= endIndex
        unless include(@markers[i], marker)
          throw new Error("Node at #{@index} should have marker #{marker} at level #{i} pointer to node at #{nextIndex} <= #{endIndex}")
        @verifyNotMarkedBelowLevel(marker, i, nextIndex) if i > 0
        return
    throw new Error("Node at #{@index} should have marker #{marker} on some forward pointer to an index <= #{endIndex}, but it doesn't")

  verifyNotMarkedBelowLevel: (marker, level, untilIndex) ->
    for i in [level - 1..0]
      if include(@markers[i], marker)
        throw new Error("Node at #{@index} should not have marker #{marker} at level #{i} pointer to node at #{@next[i].index}")

    if @next[0].index < untilIndex
      @next[0].verifyNotMarkedBelowLevel(marker, level, untilIndex)
