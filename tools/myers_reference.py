import random, itertools

def myers(a, b, maxD):
    n, m = len(a), len(b)
    if n == 0 and m == 0: return []
    if n == 0: return [("ins", j) for j in range(m)]
    if m == 0: return [("del", i) for i in range(n)]
    limit = min(n + m, maxD)
    offset = limit + 1
    v = [0] * (2 * limit + 3)
    trace = []
    found = -1
    for d in range(0, limit + 1):
        trace.append([] if d == 0 else v[offset - (d - 1): offset + (d - 1) + 1])
        k = -d
        while k <= d:
            if k == -d or (k != d and v[offset + k - 1] < v[offset + k + 1]):
                x = v[offset + k + 1]
            else:
                x = v[offset + k - 1] + 1
            y = x - k
            while x < n and y < m and a[x] == b[y]:
                x += 1; y += 1
            v[offset + k] = x
            if x >= n and y >= m:
                found = d; break
            k += 2
        if found >= 0: break
    if found < 0: return None
    ops = []
    x, y, d = n, m, found
    while d > 0:
        vd = trace[d]
        k = x - y
        if k == -d or (k != d and vd[k - 1 + d - 1] < vd[k + 1 + d - 1]):
            prevK = k + 1
        else:
            prevK = k - 1
        prevX = vd[prevK + d - 1]; prevY = prevX - prevK
        while x > prevX and y > prevY:
            ops.append(("eq", x - 1, y - 1)); x -= 1; y -= 1
        if x == prevX: ops.append(("ins", prevY))
        else: ops.append(("del", prevX))
        x, y, d = prevX, prevY, d - 1
    while x > 0 and y > 0:
        ops.append(("eq", x - 1, y - 1)); x -= 1; y -= 1
    assert x == 0 and y == 0, (x, y)
    ops.reverse()
    return ops

def lcs_len(a, b):
    dp = [[0]*(len(b)+1) for _ in range(len(a)+1)]
    for i in range(len(a)):
        for j in range(len(b)):
            dp[i+1][j+1] = dp[i][j]+1 if a[i]==b[j] else max(dp[i][j+1], dp[i+1][j])
    return dp[len(a)][len(b)]

def apply(ops, a, b):
    out = []
    ai = bi = 0
    for op in ops:
        if op[0] == "eq":
            assert op[1] == ai and op[2] == bi, (op, ai, bi)
            assert a[ai] == b[bi]
            out.append(b[bi]); ai += 1; bi += 1
        elif op[0] == "del":
            assert op[1] == ai, (op, ai); ai += 1
        else:
            assert op[1] == bi, (op, bi); out.append(b[bi]); bi += 1
    assert ai == len(a) and bi == len(b)
    return out

random.seed(1)
cases = 0
for _ in range(20000):
    n, m = random.randint(0, 9), random.randint(0, 9)
    a = [random.choice("abc") for _ in range(n)]
    b = [random.choice("abc") for _ in range(m)]
    ops = myers(a, b, 10**6)
    assert apply(ops, a, b) == b
    cost = sum(1 for o in ops if o[0] != "eq")
    assert cost == n + m - 2 * lcs_len(a, b), (a, b, ops)
    cases += 1
# cost cap behaviour
assert myers(list("abcdef"), list("uvwxyz"), 3) is None
assert myers(list("abcdef"), list("abcxef"), 2) is not None
print("ok", cases, "random cases; cap behaviour ok")
