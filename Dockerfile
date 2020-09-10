FROM debian:testing-slim

RUN apt update
RUN apt install -y perl
RUN apt install -y libdbd-sqlite3-perl
RUN apt install -y libdbix-class-perl
RUN apt install -y libdbix-class-schema-loader-perl
RUN apt install -y libmojolicious-perl
RUN apt install -y liblocal-lib-perl

WORKDIR /v073
COPY . .

CMD perl script/v073 daemon --listen http://*:$PORT
