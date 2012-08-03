drop table users;
CREATE TABLE users (
    userid MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    username varchar(150) NOT NULL,
    password varchar(31) NOT NULL,
    salt varchar(22) NOT NULL,
    push_messages BOOL
);

drop table inserts;
create table inserts(
    entity varchar(100),
    object_id INT,
    userid INT,
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

drop table modifications;
create table modifications(
    entity varchar(100),
    object_id INT,
    userid INT,
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

drop table deletes;
create table deletes(
    entity varchar(100),
    object_id INT,
    userid INT,
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
