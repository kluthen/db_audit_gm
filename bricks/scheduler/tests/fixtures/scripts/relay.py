# Stack test fixture of the scheduler brick (v0.5): a script job on an HTTP
# connection (master spec 7.2). Posts a JSON order and an NDJSON shipment to
# the stub, then a call the stub refuses (503): the script gets every
# answer, whatever its status, and decides; returns the rows it "wrote".


def relay(conns, options, log):
    lab = conns["lab"]
    order = lab.post("/orders", {"tests": ["cbc"], "n": 1, "urgent": False})
    shipment = lab.post("/shipments", b'{"row": 1}\n{"row": 2}\n', headers={"Content-Type": "application/x-ndjson"})
    refused = lab.post("/fail")
    log(f"order {order.status} {order.json()['accession']}, shipment {shipment.status}, refused {refused.status}")
    return 1
