"""A task's connections to one schedule connection (master spec 7.1: each
task has its own connections; pooling is part of the behaviour).

`pool: {size: N}`: at most N sessions, opened when first needed and kept
open; a call waits for a free one when all N are busy; a session that
broke is closed and replaced at the next call. `pool: {per-call: true}`:
a session opened for each call and closed after it.
"""

import asyncio
import contextlib

from .drivers import get_driver


class Pool:
    def __init__(self, connection, password, application_name):
        self.connection = connection
        self.password = password
        self.application_name = application_name
        self.driver = get_driver(connection.driver)
        self.per_call = connection.per_call
        self._slots = None if self.per_call else asyncio.Semaphore(connection.pool_size)
        self._idle = []
        self._open = set()
        self.closing = False

    @contextlib.asynccontextmanager
    async def session(self):
        """Yields an open session; raises DriverError (connect=True) when it
        cannot be opened."""
        if self.per_call:
            s = await self.driver.connect(self.connection, self.password, self.application_name)
            self._open.add(s)
            try:
                yield s
            finally:
                self._open.discard(s)
                await s.close()
            return
        async with self._slots:
            s = None
            while self._idle and s is None:
                candidate = self._idle.pop()
                if candidate.broken:
                    self._open.discard(candidate)
                    await candidate.close()
                else:
                    s = candidate
            if s is None:
                s = await self.driver.connect(self.connection, self.password, self.application_name)
                self._open.add(s)
            try:
                yield s
            finally:
                if s.broken or self.closing:
                    self._open.discard(s)
                    await s.close()
                else:
                    self._idle.append(s)

    def size_open(self):
        return len(self._open)

    async def close(self):
        """Closes the idle sessions now; busy ones close when their call ends."""
        self.closing = True
        idle, self._idle = self._idle, []
        for s in idle:
            self._open.discard(s)
            await s.close()

    async def close_all(self):
        self.closing = True
        for s in list(self._open):
            await s.close()
        self._open.clear()
        self._idle = []
