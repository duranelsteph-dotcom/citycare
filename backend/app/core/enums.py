from enum import StrEnum


class UserRole(StrEnum):
    YOUNG = "YOUNG"
    PARENT = "PARENT"
    RELATIVE = "RELATIVE"
    AUTHORITY = "AUTHORITY"


class GuardianRelation(StrEnum):
    PARENT = "PARENT"
    RELATIVE = "RELATIVE"
    OTHER = "OTHER"


class GuardianLinkStatus(StrEnum):
    PENDING = "PENDING"
    ACTIVE = "ACTIVE"
    REVOKED = "REVOKED"


class CircleRole(StrEnum):
    """Rôle local au cercle. N'accorde aucune permission GuardianLink."""

    OWNER = "OWNER"
    MEMBER = "MEMBER"


class AlertStatus(StrEnum):
    CREATED = "CREATED"
    ACTIVE = "ACTIVE"
    ACKNOWLEDGED = "ACKNOWLEDGED"
    IN_PROGRESS = "IN_PROGRESS"
    RESOLVED = "RESOLVED"
    CANCELLED = "CANCELLED"


class AlertSource(StrEnum):
    MOBILE = "MOBILE"
    IOT = "IOT"
    RELATIVE = "RELATIVE"
    VOICE = "VOICE"
    SYSTEM = "SYSTEM"


class AlertSeverity(StrEnum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class LocationSource(StrEnum):
    PHONE = "PHONE"
    IOT = "IOT"


class TrackerStatus(StrEnum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    LOW_BATTERY = "LOW_BATTERY"
    SIGNAL_LOST = "SIGNAL_LOST"
    REMOVED = "REMOVED"


class TrackerEventType(StrEnum):
    LOCATION = "LOCATION"
    SOS = "SOS"
    GEOFENCE_EXIT = "GEOFENCE_EXIT"
    GEOFENCE_ENTER = "GEOFENCE_ENTER"
    SIGNAL_LOST = "SIGNAL_LOST"
    SIGNAL_RESTORED = "SIGNAL_RESTORED"
    DEVICE_REMOVED = "DEVICE_REMOVED"
    LOW_BATTERY = "LOW_BATTERY"
    RISK_ZONE_ENTER = "RISK_ZONE_ENTER"
    ANOMALY = "ANOMALY"


class CaseStatus(StrEnum):
    OPEN = "OPEN"
    SEARCHING = "SEARCHING"
    FOUND = "FOUND"
    CLOSED = "CLOSED"


class CasePriority(StrEnum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class TestimonyStatus(StrEnum):
    SUBMITTED = "SUBMITTED"
    UNDER_REVIEW = "UNDER_REVIEW"
    VERIFIED = "VERIFIED"
    REJECTED = "REJECTED"


class SearchZoneKind(StrEnum):
    PROBABLE_DISPLACEMENT = "PROBABLE_DISPLACEMENT"
    PRIORITY_SEARCH = "PRIORITY_SEARCH"


class SearchPriority(StrEnum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class RiskLevel(StrEnum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class ConsistencyLevel(StrEnum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class NotificationType(StrEnum):
    SOS = "SOS"
    GEOFENCE_EXIT = "GEOFENCE_EXIT"
    LOW_BATTERY = "LOW_BATTERY"
    SIGNAL_LOST = "SIGNAL_LOST"
    RISK_ZONE_ENTER = "RISK_ZONE_ENTER"
    ANOMALY = "ANOMALY"
    DEVICE_REMOVED = "DEVICE_REMOVED"
    POSITION_SHARE = "POSITION_SHARE"
    MISSING_CASE = "MISSING_CASE"
    SEARCH_UPDATE = "SEARCH_UPDATE"
    TESTIMONY = "TESTIMONY"


class TrackingMode(StrEnum):
    NORMAL = "NORMAL"
    SURVEILLANCE = "SURVEILLANCE"
    EMERGENCY = "EMERGENCY"
    POWER_SAVE = "POWER_SAVE"
