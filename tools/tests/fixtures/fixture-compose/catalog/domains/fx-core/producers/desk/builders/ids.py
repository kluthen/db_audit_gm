"""The test core's builder."""


def owner(intensity, options, rng=None):
    return "INSERT INTO owners (id, name) VALUES (%s, 'x')", [rng.randint(1, 10)]
