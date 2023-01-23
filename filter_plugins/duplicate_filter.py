#!/usr/bin/python

class FilterModule(object):
    def filters(self):
        return {'duplicates': self.duplicates}

    def duplicates(self, items):
        sums = {}
        result = []

        for item in items:
            if item not in sums:
                sums[item] = 1
            else:
                if sums[item] == 1:
                    result.append(item)
                sums[item] += 1
        return result