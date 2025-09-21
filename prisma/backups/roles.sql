
\restrict vEFF3UDxU51U2iuO93FK2rDktk5SfGYdDwHCJJ7GQeXRq5vtsRht9pGQpxA2xqS

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

CREATE ROLE "cli_login_postgres";
ALTER ROLE "cli_login_postgres" WITH NOINHERIT NOCREATEROLE NOCREATEDB LOGIN NOBYPASSRLS VALID UNTIL '2025-09-15 09:26:56.985526+00';

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

GRANT "postgres" TO "cli_login_postgres";

\unrestrict vEFF3UDxU51U2iuO93FK2rDktk5SfGYdDwHCJJ7GQeXRq5vtsRht9pGQpxA2xqS

RESET ALL;
