"""Arrivals of a stream (master spec 7.1).

A stream's rate is given per minute (or second, hour) at intensity 1.0;
its rate at a moment is rate x intensity x the shape's multiplier for the
moment's UTC weekday and hour. Arrivals are a Poisson process of that
rate, or even: the n-th arrival comes when the integral of the rate since
the previous one reaches 1 (even) or an exponential draw of mean 1
(Poisson), so a rate that changes at an hour boundary or a timeline change
is followed exactly.
"""

from .timeutil import next_hour, weekday_hour


def shape_multiplier(shape, ts):
    """`shape`: {weekday: [24 multipliers]} or None (multiplier 1)."""
    if shape is None:
        return 1.0
    day, hour = weekday_hour(ts)
    return shape[day][hour]


def rate_function(stream, intensity, shapes):
    def rate_at(ts):
        shape = shapes.get(stream.shape) if stream.shape else None
        return stream.rate * intensity * shape_multiplier(shape, ts)
    return rate_at


def draw_need(rng, arrivals):
    return rng.expovariate(1.0) if arrivals == "poisson" else 1.0


def next_arrival(t, need, rate_at, limit, boundary_after=next_hour):
    """Integrates `rate_at` (constant between `boundary_after` points) from
    `t` until it reaches `need`, but not past `limit`. Returns
    (arrival time, 0.0), or (limit, the need still to integrate)."""
    while t < limit:
        end = min(boundary_after(t), limit)
        r = rate_at(t)
        if r > 0 and need <= r * (end - t):
            return t + need / r, 0.0
        need -= r * (end - t)
        t = end
    return limit, max(need, 0.0)
