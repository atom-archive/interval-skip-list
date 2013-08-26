IntervalSkipList = require '../src/interval-skip-list'
{random, times} = require 'underscore'

describe "IntervalSkipList", ->
  list = null

  beforeEach ->
    list = new IntervalSkipList

  getRandomInterval = ->
    a = random(0, 100)
    b = random(0, 100)
    [Math.min(a, b), Math.max(a, b)]

  it "can insert intervals without violating the marker invariant", ->
    times 100, ->
      list = new IntervalSkipList
      times 100, (i) ->
        list.insert(i.toString(), getRandomInterval()...)
        list.verifyMarkerInvariant()
