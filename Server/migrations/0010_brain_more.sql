-- Learning loop: owners rate answers; poor ones leave the library.
alter table ai_library add column good bigint not null default 0, add column bad bigint not null default 0;
-- Weather watch: a ~10 km cell (rounded coordinates, never exact), the app language, and whether the
-- owner keeps plants outdoors or on a balcony. Cleared when the owner turns it off.
alter table devices add column weather_cell text, add column weather_lang text, add column weather_alert_on date;
create index on devices (weather_cell) where weather_cell is not null;
