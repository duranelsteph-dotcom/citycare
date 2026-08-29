from datetime import date, datetime, time
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.core.enums import (
    AlertSeverity,
    AlertSource,
    AlertStatus,
    CasePriority,
    CaseStatus,
    ConsistencyLevel,
    GuardianRelation,
    GuardianLinkStatus,
    LocationSource,
    NotificationType,
    RiskLevel,
    SearchPriority,
    SearchZoneKind,
    TestimonyStatus,
    TrackerEventType,
    TrackerStatus,
    TrackingMode,
    UserRole,
)


class OrmModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class UserRead(OrmModel):
    id: UUID
    full_name: str
    email: str | None
    phone: str
    role: UserRole
    is_active: bool
    created_at: datetime
    updated_at: datetime


class YoungPersonRead(OrmModel):
    id: UUID
    user_id: UUID
    display_name: str
    birth_date: date | None
    photo_url: str | None
    notes: str | None
    created_at: datetime
    updated_at: datetime


class GuardianLinkRead(OrmModel):
    id: UUID
    guardian_user_id: UUID
    young_person_id: UUID
    relation: GuardianRelation
    status: GuardianLinkStatus
    can_view_location: bool
    can_receive_alerts: bool
    can_trigger_alert: bool
    can_report_missing: bool
    can_manage_zones: bool
    can_manage_tracker: bool
    guardian_name: str | None = None
    guardian_phone: str | None = None
    young_display_name: str | None = None
    young_phone: str | None = None


class EmergencyContactRead(OrmModel):
    id: UUID
    young_person_id: UUID
    name: str
    phone: str
    user_id: UUID | None


class GPSTrackerRead(OrmModel):
    id: UUID
    young_person_id: UUID
    device_uid: str
    label: str
    status: TrackerStatus
    tracking_mode: TrackingMode
    battery_level: int | None
    signal_strength: int | None
    last_seen_at: datetime | None
    last_latitude: float | None
    last_longitude: float | None
    firmware_version: str | None
    young_display_name: str | None = None


class TrackerLocationRead(OrmModel):
    id: UUID
    tracker_id: UUID | None
    young_person_id: UUID
    source: LocationSource
    latitude: float
    longitude: float
    accuracy: float | None
    altitude: float | None
    speed: float | None
    heading: float | None
    recorded_at: datetime
    battery_level: int | None
    signal_strength: int | None
    is_stale: bool = False
    age_seconds: int = 0


class TrackerEventRead(OrmModel):
    id: UUID
    tracker_id: UUID | None
    young_person_id: UUID
    event_type: TrackerEventType
    recorded_at: datetime
    latitude: float | None
    longitude: float | None
    payload: str | None


class PositionShareRead(OrmModel):
    id: UUID
    young_person_id: UUID
    target_user_id: UUID
    starts_at: datetime
    expires_at: datetime | None
    is_revoked: bool
    revoked_at: datetime | None
    is_active: bool = False
    target_display_name: str | None = None
    young_display_name: str | None = None


class SafetyZoneScheduleRead(OrmModel):
    id: UUID
    zone_id: UUID
    weekday: int = Field(description="0 = Monday … 6 = Sunday. If end_time <= start_time, window crosses midnight.")
    start_time: time
    end_time: time


class SafetyZoneRead(OrmModel):
    id: UUID
    young_person_id: UUID
    name: str
    latitude: float
    longitude: float
    radius_meters: float
    is_active: bool
    accuracy_tolerance_meters: float
    min_exit_duration_seconds: int
    schedules: list[SafetyZoneScheduleRead] = []
    schedule_active_now: bool = False
    inside_on_last_fix: bool = False


class RiskZoneRead(OrmModel):
    id: UUID
    name: str
    latitude: float
    longitude: float
    radius_meters: float
    is_active: bool
    incident_count: int
    typical_start_hour: int | None
    typical_end_hour: int | None
    is_hour_active_now: bool = False


class AlertRead(OrmModel):
    id: UUID
    young_person_id: UUID
    triggered_by_user_id: UUID | None
    source: AlertSource
    status: AlertStatus
    severity: AlertSeverity
    latitude: float | None
    longitude: float | None
    accuracy: float | None
    triggered_at: datetime
    battery_level: int | None
    tracker_status: str | None
    description: str | None
    last_known_latitude: float | None
    last_known_longitude: float | None
    last_known_at: datetime | None
    created_at: datetime
    updated_at: datetime
    young_display_name: str | None = None


class NotificationContext(BaseModel):
    """Contexte d'ouverture. Inbox toujours ; push FCM en plus si configuré. Pas une position actuelle."""

    channel: str = "IN_APP"
    target: str
    young_person_id: UUID | None = None
    young_display_name: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    zone_name: str | None = None
    is_live_position: bool = False
    disclaimer: str


class NotificationRead(OrmModel):
    id: UUID
    recipient_user_id: UUID
    notification_type: NotificationType
    title: str
    body: str
    is_read: bool
    alert_id: UUID | None
    case_id: UUID | None
    payload: str | None
    created_at: datetime
    context: NotificationContext | None = None


class MissingPersonCaseRead(OrmModel):
    id: UUID
    young_person_id: UUID
    reported_by_user_id: UUID
    occurred_at: datetime
    last_known_latitude: float | None
    last_known_longitude: float | None
    last_known_at: datetime | None
    description: str | None
    clothing: str | None
    circumstances: str | None
    last_seen_by: str | None
    photo_url: str | None
    snapshot: dict | None = None
    status: CaseStatus
    priority: CasePriority
    created_at: datetime
    updated_at: datetime
    young_display_name: str | None = None
    reporter_name: str | None = None


class TestimonyRead(OrmModel):
    """Témoignage humain. Pas une preuve. La cohérence GPS est une estimation par règles."""

    id: UUID
    case_id: UUID
    submitted_by_user_id: UUID | None
    description: str
    latitude: float
    longitude: float
    observed_at: datetime
    photo_url: str | None
    status: TestimonyStatus
    consistency: ConsistencyLevel | None
    consistency_note: str | None
    submitter_name: str | None = None
    disclaimer: str = (
        "Témoignage humain. Aide à la décision par règles métier. "
        "Ce n'est pas un kidnapping confirmé, pas la position actuelle, pas une preuve."
    )


class SearchZoneRead(OrmModel):
    """Zone estimée. Jamais la position réelle. PROBABLE_DISPLACEMENT ou PRIORITY_SEARCH."""

    id: UUID
    case_id: UUID
    kind: SearchZoneKind
    priority: SearchPriority
    center_latitude: float
    center_longitude: float
    radius_meters: float
    explanation: str
    computed_at: datetime
    disclaimer: str = (
        "Zone de recherche estimée. Ce n'est pas la position actuelle, "
        "pas un kidnapping confirmé, pas un itinéraire, pas une zone prioritaire."
    )


class RiskAnalysisRead(OrmModel):
    id: UUID
    case_id: UUID | None
    young_person_id: UUID
    risk_level: RiskLevel
    explanation: str
    factors: str | None
    method: str
    created_at: datetime


class IncidentRead(OrmModel):
    id: UUID
    risk_zone_id: UUID | None
    title: str
    description: str | None
    latitude: float
    longitude: float
    occurred_at: datetime
    source: str | None
    count: int


class TrajectoryPointRead(OrmModel):
    """Point d'une trajectoire : dérivé de TrackerLocation, pas une table séparée."""

    location_id: UUID
    latitude: float
    longitude: float
    recorded_at: datetime
    speed: float | None
    heading: float | None
    source: LocationSource
    gap_after: bool = False


class TrajectoryRead(OrmModel):
    young_person_id: UUID
    points: list[TrajectoryPointRead]
    access: str = "SELF"
    point_count: int = 0
    gap_count: int = 0
    distance_meters: float = 0
    started_at: datetime | None = None
    ended_at: datetime | None = None
    gap_threshold_seconds: int = 600
    disclaimer: str = (
        "Trajectoire reconstruite à partir des positions enregistrées. "
        "Ce n'est pas un suivi en direct, pas la position actuelle, "
        "pas une trajectoire analysée ni une zone de recherche."
    )


class SearchIntelligenceRead(BaseModel):
    """Aide à la décision par règles. Pas un modèle ML. Une zone probable n'est pas la position réelle."""

    id: UUID
    case_id: UUID | None
    young_person_id: UUID
    risk_level: RiskLevel
    explanation: str
    method: str
    created_at: datetime
    updated_at: datetime
    factors: dict
    has_search_zone: bool = False
    disclaimer: str


class AiAnalysisRead(BaseModel):
    """Analyse IA par règles. Pas un modèle entraîné. Ne confirme jamais un kidnapping."""

    id: UUID
    case_id: UUID | None
    young_person_id: UUID
    risk_level: RiskLevel
    explanation: str
    method: str
    created_at: datetime
    updated_at: datetime
    factors: dict
    trained_model: bool = False
    disclaimer: str


class EmergencySnapshot(BaseModel):
    """Mode urgence : faits connus. Pas un GPS continu, pas un kidnapping confirmé."""

    young_person_id: UUID
    display_name: str
    effective_mode: TrackingMode
    last_known: TrackerLocationRead | None = None
    last_communication_at: datetime | None = None
    battery_level: int | None = None
    kit_status: str | None = None
    kit_label: str | None = None
    open_sos: AlertRead | None = None
    open_case_id: UUID | None = None
    trajectory: TrajectoryRead | None = None
    search_zones: list[SearchZoneRead] = Field(default_factory=list)
    kit_events: list[TrackerEventRead] = Field(default_factory=list)
    testimony_count: int = 0
    is_live: bool = False
    access: str
    disclaimer: str
