# Story

A small shop takes orders all day through a connection pooler, and its
reporting service reads them back. The shop works in {{customer_timezone}}.
It watches the whole with Prometheus and Grafana, and asks why the order
service's log keeps growing.
