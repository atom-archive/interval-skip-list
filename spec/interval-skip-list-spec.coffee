IntervalSkipList = require '../src/interval-skip-list'
{random, times, keys, uniq, all, any} = require 'underscore'

describe "IntervalSkipList", ->
  list = null

  buildRandomList = ->
    list = new IntervalSkipList
    times 100, (i) -> performRandomChange(list, i)
    list

  performRandomChange = (list, i) ->
    if Math.random() < .2
      removeRandomInterval(list)
    else
      insertRandomInterval(list, i.toString())

  insertRandomInterval = (list, marker) ->
    list.insert(marker, getRandomInterval()...)

  removeRandomInterval = (list) ->
    existingMarkers = keys(list.intervalsByMarker)
    if existingMarkers.length > 0
      existingMarker = existingMarkers[random(existingMarkers.length - 1)]
      list.remove(existingMarker)

  getRandomInterval = ->
    a = random(0, 100)
    b = random(0, 100)
    [Math.min(a, b), Math.max(a, b)]

  describe "::findContaining(index...)", ->
    describe "when passed a single index", ->
      it "returns markers for intervals containing the given index", ->
        times 10, ->
          list = buildRandomList()
          times 10, ->
            index = random(100)
            markers = list.findContaining(index)
            expect(uniq(markers)).toEqual markers
            for marker, [startIndex, endIndex] of list.intervalsByMarker
              if startIndex <= index <= endIndex
                expect(markers).toContain(marker)
              else
                expect(markers).not.toContain(marker)

    describe "when passed an index range", ->
      it "returns markers for intervals containing both indices", ->
        times 10, ->
          list = buildRandomList()
          times 10, ->
            indices = []
            startIndex = random(100)
            endIndex = random(100)
            [startIndex, endIndex] = [endIndex, startIndex] if startIndex > endIndex
            markers = list.findContaining(startIndex, endIndex)
            for marker, [intervalStart, intervalEnd] of list.intervalsByMarker
              if intervalStart <= startIndex <= endIndex <= intervalEnd
                expect(markers).toContain(marker)
              else
                expect(markers).not.toContain(marker)

  describe "::findIntersecting(indices...)", ->
    it "returns markers for intervals intersecting the given index range", ->
      times 10, ->
        list = buildRandomList()
        times 10, ->
          searchStartIndex = random(100)
          searchEndIndex = random(100)
          [searchStartIndex, searchEndIndex] = [searchEndIndex, searchStartIndex] if searchStartIndex > searchEndIndex
          markers = list.findIntersecting(searchStartIndex, searchEndIndex)
          for marker, [intervalStart, intervalEnd] of list.intervalsByMarker
            if intervalEnd < searchStartIndex or intervalStart > searchEndIndex
              expect(markers).not.toContain(marker)
            else
              expect(markers).toContain(marker)

  describe "::findStartingAt(index)", ->
    it "returns markers for intervals starting at the given index", ->
      times 10, ->
        list = buildRandomList()
        times 10, ->
          index = random(100)
          markers = list.findStartingAt(index)
          for marker, [startIndex, endIndex] of list.intervalsByMarker
            if startIndex is index
              expect(markers).toContain(marker)
            else
              expect(markers).not.toContain(marker)

  describe "::findEndingAt(index)", ->
    it "returns markers for intervals ending at the given index", ->
      times 10, ->
        list = buildRandomList()
        times 10, ->
          index = random(100)
          markers = list.findEndingAt(index)
          for marker, [startIndex, endIndex] of list.intervalsByMarker
            if endIndex is index
              expect(markers).toContain(marker)
            else
              expect(markers).not.toContain(marker)

  describe "::findStartingIn(startIndex, endIndex)", ->
    it "returns markers for intervals starting within the given index range", ->
      times 10, ->
        list = buildRandomList()
        times 10, ->
          [searchStartIndex, searchEndIndex] = getRandomInterval()
          markers = list.findStartingIn(searchStartIndex, searchEndIndex)
          for marker, [startIndex, endIndex] of list.intervalsByMarker
            if searchStartIndex <= startIndex <= searchEndIndex
              expect(markers).toContain(marker)
            else
              expect(markers).not.toContain(marker)

  describe "::findEndingIn(startIndex, endIndex)", ->
    it "returns markers for intervals ending within the given index range", ->
      times 10, ->
        list = buildRandomList()
        times 10, ->
          [searchStartIndex, searchEndIndex] = getRandomInterval()
          markers = list.findEndingIn(searchStartIndex, searchEndIndex)
          for marker, [startIndex, endIndex] of list.intervalsByMarker
            if searchStartIndex <= endIndex <= searchEndIndex
              expect(markers).toContain(marker)
            else
              expect(markers).not.toContain(marker)

  describe "::findContainedIn(startIndex, endIndex)", ->
    it "returns markers for intervals starting and ending within the given index range", ->
      times 10, ->
        list = buildRandomList()
        times 10, ->
          [searchStartIndex, searchEndIndex] = getRandomInterval()
          markers = list.findContainedIn(searchStartIndex, searchEndIndex)
          for marker, [startIndex, endIndex] of list.intervalsByMarker
            if searchStartIndex <= startIndex <= endIndex <= searchEndIndex
              expect(markers).toContain(marker)
            else
              expect(markers).not.toContain(marker)

  describe "maintenance of the marker invariant", ->
    it "can insert intervals without violating the marker invariant", ->
      times 10, ->
        list = new IntervalSkipList
        times 100, (i) ->
          insertRandomInterval(list, i.toString())
          list.verifyMarkerInvariant()

    it "can insert and remove intervals without violating the marker invariant", ->
      times 10, ->
        list = new IntervalSkipList
        times 100, (i) ->
          performRandomChange(list, i)
          list.verifyMarkerInvariant()

  it "can use a custom comparator function", ->
    list = new IntervalSkipList
      minIndex: [-Infinity]
      maxIndex: [Infinity]
      compare: (a, b) ->
        if a[0] < b[0]
          -1
        else if a[0] > b[0]
          1
        else
          if a[1] < b[1]
            -1
          else if a[1] > b[1]
            1
          else
            0

    list.insert("a", [1, 2], [3, 4])
    list.insert("b", [2, 1], [3, 10])
    expect(list.findContaining([1, Infinity])).toEqual ["a"]
    expect(list.findContaining([2, 20])).toEqual ["a", "b"]
