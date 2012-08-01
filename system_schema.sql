CREATE TABLE users (
    userid MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    email varchar(150) NOT NULL,
    display_name varchar(50),
    password varchar(31) NOT NULL,
    salt varchar(22) NOT NULL,
    image_url varchar(200),
    orginization varchar(200),
    profile varchar(300),
    push_messages BOOL,
    rating TINYINT
);

create table subscription(
    subscription_id MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    userid MEDIUMINT UNSIGNED NOT NULL,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    observation_type varchar(50),
    push BOOL,
    distance int
);

create table user_subscription(
    subscription_id MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    userid MEDIUMINT UNSIGNED NOT NULL,
    subscribed_to_userid int UNSIGNED NOT NULL,
    push BOOL,
    status varchar(20)
);

create table messages(
    message_id MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    userid MEDIUMINT UNSIGNED NOT NULL,
    date DATETIME NOT NULL,
    message_read BOOL,
    message varchar(255)
);

create table deletions(
    entity varchar(100),
    object_id INT,
    userid INT,
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

create table modifications(
    entity varchar(100),
    object_id INT,
    userid INT,
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

/*
create table ratings (
    observation_id INT UNSIGNED NOT NULL,
    rater_userid MEDIUMINT UNSIGNED NOT NULL,
    ratee_userid MEDIUMINT UNSIGNED NOT NULL,
    quality TINYINT,
    importance TINYINT
);
*/