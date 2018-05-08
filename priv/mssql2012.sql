USE [eodbc]
GO
CREATE TABLE [dbo].[test_types](
    [unicode] [nvarchar](max),
    [binary_data] [varbinary](max),
    [ascii_char] char(1),
    [ascii_string] varchar(250), -- limited usage, base64-like stuff
    [int32] [int],
    [int64] [bigint],
    [int8] tinyint,
    [enum_char] [nvarchar](1),
    [bool_flag] smallint
)
GO
