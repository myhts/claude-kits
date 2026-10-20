-- Tables for the transactions skill's proofs (TransactionTrapsTest): each trap reads or writes one of these.
create table tx_order    (id bigint generated always as identity primary key, item varchar(100) not null);
create table tx_payment  (id bigint generated always as identity primary key, amount bigint not null);
create table tx_audit    (id bigint generated always as identity primary key, message varchar(200) not null);
create table tx_customer (id bigint generated always as identity primary key, email varchar(200) not null);
create table tx_wallet   (id bigint generated always as identity primary key, balance bigint not null);
create table tx_versioned_wallet (id bigint generated always as identity primary key, balance bigint not null,
                                  version bigint not null default 0);
