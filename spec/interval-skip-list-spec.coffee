IntervalSkipList = require '../src/interval-skip-list'
{random, times, keys} = require 'underscore'

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

  describe "::findContaining(index)", ->
    it "returns markers for intervals containing the given index", ->
      times 10, ->
        list = buildRandomList()
        times 10, ->
          index = random(100)
          markers = list.findContaining(index)
          for marker, [startIndex, endIndex] of list.intervalsByMarker
            if startIndex <= index <= endIndex
              expect(markers).toContain(marker)
            else
              expect(markers).not.toContain(marker)

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
