create table author (
    id   bigint generated always as identity primary key,
    name varchar(100) not null
);

create table book (
    id        bigint generated always as identity primary key,
    author_id bigint not null references author (id),
    title     varchar(200) not null,
    version   bigint not null default 0
);
create index book_author_id on book (author_id);   -- foreign keys aren't indexed automatically in Postgres

create table outbox (
    id           bigint generated always as identity primary key,
    topic        varchar(100) not null,
    message_key  varchar(100) not null,
    payload      text not null,
    created_at   timestamptz not null default now(),
    published_at timestamptz
);
create index outbox_unpublished on outbox (id) where published_at is null;
