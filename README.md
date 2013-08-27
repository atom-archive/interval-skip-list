# Interval Skip List [![Build Status](https://travis-ci.org/atom/interval-skip-list.png)](https://travis-ci.org/atom/interval-skip-list)

This data structure maps intervals to values and allows you to find all
intervals that contain an index in `O(ln(n))`, where `n` is the number of
intervals stored. This implementation is based on the paper
[The Interval Skip List](https://www.cise.ufl.edu/tr/DOC/REP-1992-45.pdf) by
Eric N. Hanson.

```coffeescript
IntervalSkipList = require 'interval-skip-list'
list = new IntervalSkipList

list.insert('a', 2, 7)
list.insert('b', 1, 5)
list.insert('c', 8, 8)

list.findContaining(1) # => ['b']
list.findContaining(2) # => ['b', 'a']
list.findContaining(8) # => ['c']

list.remove('b')

list.findContaining(2) # => ['a']
```
