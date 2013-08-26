IntervalSkipList = require '../src/interval-skip-list'
{random, times, keys} = require 'underscore'

describe "IntervalSkipList", ->
  list = null

  beforeEach ->
    list = new IntervalSkipList

  getRandomInterval = ->
    a = random(0, 100)
    b = random(0, 100)
    [Math.min(a, b), Math.max(a, b)]

  it "can insert intervals without violating the marker invariant", ->
    times 10, ->
      list = new IntervalSkipList
      times 100, (i) ->
        list.insert(i.toString(), getRandomInterval()...)
        list.verifyMarkerInvariant()

  it "can insert and remove intervals without violating the marker invariant", ->
    times 10, ->
      list = new IntervalSkipList
      times 100, (i) ->
        existingMarkers = keys(list.intervalsByMarker)
        if Math.random() < .3 and existingMarkers.length > 0
          existingMarker = existingMarkers[random(existingMarkers.length - 1)]
          list.remove(existingMarker)
        else
          list.insert(i.toString(), getRandomInterval()...)
        list.verifyMarkerInvariant()
