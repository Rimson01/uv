"""UV-index connectivity; seam copies never share an index."""

def island_vertices(edges, selected, used):
    adjacency = {i: set() for i in used}
    for a, b in edges:
        if a not in adjacency or b not in adjacency:
            raise ValueError('Edge references an unused vertex')
        adjacency[a].add(b)
        adjacency[b].add(a)
    result = set(selected) & set(used)
    queue = list(result)
    for vertex in queue:
        for neighbor in adjacency[vertex] - result:
            result.add(neighbor)
            queue.append(neighbor)
    return result


def emit_maxscript():
    return '''fn lsyUVIslandFromEdges vertexCount links picked used =
(
    local adjacency = for i=1 to vertexCount collect #()
    for edge in links do
    (
        append adjacency[edge[1]] edge[2]
        append adjacency[edge[2]] edge[1]
    )
    local result = picked * used
    local queue = result as array
    local cursor = 1
    while cursor <= queue.count do
    (
        for id in adjacency[queue[cursor]] where not result[id] do
        (
            result[id] = true
            append queue id
        )
        cursor += 1
    )
    result
)
'''
