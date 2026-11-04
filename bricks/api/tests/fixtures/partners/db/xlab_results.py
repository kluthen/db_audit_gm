"""The external lab's side: reads the customer's order through its API, then
records it in the partner's own database (a SECURITY DEFINER function)."""

import gm_api


def fetch_and_record(order_id):
    answer = gm_api.client("lab-api").get(f"/orders/{order_id}")
    if answer.status != 200:
        return {"order_id": order_id, "lab_api_status": answer.status}
    order = answer.json()
    with gm_api.connection("partners") as conn:
        by = conn.execute("SELECT record_result(%s, %s)", (order["id"], order["label"])).fetchone()[0]
        conn.commit()
    return {"order": order, "lab_api_status": answer.status, "recorded_by": by}
