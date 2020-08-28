create table voting (
    id      integer primary key autoincrement,
    type    text    not null references type(name),
    token   text    not null unique,
    text    text,
    started integer default 0,
    closed  integer default 0
);

create table type (
    name    text    primary key
);

create table option (
    id      integer primary key autoincrement,
    type    text    not null references type(name),
    text    text    not null
);

create table vote (
    id      integer primary key autoincrement,
    voting  integer not null references voting(id),
    option  integer not null references option(id)
);

create table token (
    name    text    primary key,
    voting  integer not null references voting(id),
    voted   integer default 0
);
