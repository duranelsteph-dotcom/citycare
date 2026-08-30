from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.circle import (
    CircleCreate,
    CircleInviteCodeRead,
    CircleJoinRequest,
    CircleMemberRead,
    CircleRead,
    CircleUpdate,
)
from app.services.circle_service import (
    CircleError,
    create_circle,
    get_circle,
    get_invite,
    join_circle,
    leave_circle,
    list_circles,
    list_members,
    regenerate_invite,
    remove_member,
    update_circle,
)

router = APIRouter(prefix="/circles", tags=["circles"])


def _raise(exc: CircleError) -> None:
    raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.get("", response_model=list[CircleRead])
def get_circles(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[CircleRead]:
    try:
        return list_circles(db, user)
    except CircleError as exc:
        _raise(exc)


@router.post("", response_model=CircleRead)
def post_circle(
    payload: CircleCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CircleRead:
    try:
        return create_circle(db, user, payload)
    except CircleError as exc:
        _raise(exc)


@router.post("/join", response_model=CircleRead)
def post_join(
    payload: CircleJoinRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CircleRead:
    try:
        return join_circle(db, user, payload)
    except CircleError as exc:
        _raise(exc)


@router.get("/{circle_id}", response_model=CircleRead)
def get_one(
    circle_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CircleRead:
    try:
        return get_circle(db, user, circle_id)
    except CircleError as exc:
        _raise(exc)


@router.patch("/{circle_id}", response_model=CircleRead)
def patch_circle(
    circle_id: UUID,
    payload: CircleUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CircleRead:
    try:
        return update_circle(db, user, circle_id, payload)
    except CircleError as exc:
        _raise(exc)


@router.get("/{circle_id}/invite-code", response_model=CircleInviteCodeRead)
def read_invite_code(
    circle_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CircleInviteCodeRead:
    try:
        return get_invite(db, user, circle_id)
    except CircleError as exc:
        _raise(exc)


@router.post("/{circle_id}/invite-code", response_model=CircleInviteCodeRead)
def post_invite_code(
    circle_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CircleInviteCodeRead:
    try:
        return regenerate_invite(db, user, circle_id)
    except CircleError as exc:
        _raise(exc)


@router.post("/{circle_id}/leave", status_code=204)
def post_leave(
    circle_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    try:
        leave_circle(db, user, circle_id)
    except CircleError as exc:
        _raise(exc)


@router.get("/{circle_id}/members", response_model=list[CircleMemberRead])
def get_members(
    circle_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[CircleMemberRead]:
    try:
        return list_members(db, user, circle_id)
    except CircleError as exc:
        _raise(exc)


@router.delete("/{circle_id}/members/{user_id}", status_code=204)
def delete_member(
    circle_id: UUID,
    user_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    try:
        remove_member(db, user, circle_id, user_id)
    except CircleError as exc:
        _raise(exc)
