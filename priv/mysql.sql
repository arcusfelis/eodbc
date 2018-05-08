CREATE TABLE test_types(
    unicode text CHARACTER SET utf8mb4,
    `binary_data` blob,
    `ascii_char` character(1),
    `ascii_string` varchar(250),
    `int32` int,
    `int64` bigint,
    `int8` tinyint,
    `enum_char` ENUM('A','B', 'C'),
    `bool_flag` boolean
);
