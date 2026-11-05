"""portal-api's session endpoint (vet-portal; capture W3 item 5): POST /login
{email, password} answers 201 {token} and sets the cookie portal_session to
the token, 401 for a wrong e-mail or password, 423 while the account is
locked; POST /logout ends the cookie's session, 204, or 401 when it names no
open session. The owner endpoints read the same cookie: gm_api's client never
lets a caller set Authorization, so the owners' route sends a cookie, as a
browser does. Imports FastAPI, Pydantic, the standard library and db/ only."""

from fastapi import APIRouter, Cookie, HTTPException, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from db import session

router = APIRouter()

COOKIE = "portal_session"


class Login(BaseModel):
    email: str = Field(min_length=1, max_length=320)
    password: str = Field(min_length=1, max_length=200)


@router.post("/login")
def login(body: Login):
    """portal_login: a new session's token, its hash stored."""
    result, token = session.login(body.email, body.password)
    if result == "ok":
        answer = JSONResponse(status_code=201, content={"token": token})
        answer.set_cookie(COOKIE, token, path="/", httponly=True, samesite="strict")
        return answer
    if result == "locked":
        raise HTTPException(status_code=423, detail="locked: too many failed logins, try again later")
    raise HTTPException(status_code=401, detail="wrong e-mail or password")


@router.post("/logout")
def logout(portal_session: str | None = Cookie(default=None)):
    """The session ended (portal_logout) and the cookie cleared."""
    if not portal_session or not session.logout(portal_session):
        raise HTTPException(status_code=401, detail="no open session")
    answer = Response(status_code=204)
    answer.delete_cookie(COOKIE, path="/")
    return answer
