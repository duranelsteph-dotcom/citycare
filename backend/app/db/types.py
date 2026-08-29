from sqlalchemy import Enum as SAEnum


def enum_column(enum_cls, **kwargs):
    return SAEnum(
        enum_cls,
        native_enum=False,
        values_callable=lambda members: [member.value for member in members],
        **kwargs,
    )
