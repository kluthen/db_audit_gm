# Stack test fixture of the scheduler brick (v0.5): a call's builder, its
# return the JSON body of POST /orders.
def order(intensity, options, rng=None):
    return {"urgent": rng.random() < options["urgent_share"], "tests": ["cbc", "chem"], "n": int(10 * intensity)}
