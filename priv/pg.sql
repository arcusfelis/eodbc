CREATE TYPE test_enum_char AS ENUM('A','B', 'C');
CREATE TABLE test_types(
    unicode text,
    binary_data bytea,
    ascii_char character(1),
    ascii_string varchar(250),
    int32 integer,
    int64 bigint,
    int8 smallint, -- has no tinyint, so the next one is 2-bytes smallint
    enum_char test_enum_char,
    bool_flag boolean
);
