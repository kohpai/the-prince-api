CREATE OR REPLACE FUNCTION public.new_customer ()
    RETURNS public.customer
    AS $$
    INSERT INTO public.customer (id)
        VALUES (current_setting('jwt.claims.firebase_uid', TRUE))
    RETURNING
        *
$$
LANGUAGE SQL
STRICT
SECURITY DEFINER;

COMMENT ON FUNCTION public.new_customer () IS 'Add a new customer from Firebase user';

GRANT EXECUTE ON FUNCTION public.new_customer () TO authuser;

CREATE OR REPLACE FUNCTION public.top_up (order_id text, amount money)
    RETURNS public.customer
    AS $$
    UPDATE
        public.customer
    SET
        balance = balance + amount
    WHERE
        id = current_setting('jwt.claims.firebase_uid', TRUE)
    RETURNING
        *
$$
LANGUAGE SQL
STRICT
SECURITY DEFINER;

COMMENT ON FUNCTION public.top_up (order_id text, amount money) IS 'Top up the customer''s balance';

GRANT EXECUTE ON FUNCTION public.top_up (order_id text, amount money) TO authuser;

CREATE OR REPLACE FUNCTION public.current_user()
    RETURNS public.customer
    AS $$
DECLARE
    c public.customer;
BEGIN
    SELECT
        * INTO c
    FROM
        public.customer
    WHERE
        id = current_setting('jwt.claims.firebase_uid', TRUE);
    IF c IS NULL THEN
        SELECT
            public.new_customer () INTO c;
    END IF;
    RETURN c;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;

COMMENT ON FUNCTION public.current_user() IS 'Get current logged-in user';

GRANT EXECUTE ON FUNCTION public.current_user() TO authuser;

CREATE OR REPLACE FUNCTION public.parse_page_range (pr text)
    RETURNS smallint
    AS $$
DECLARE
    trimmed_pr text;
    a_range text;
    range_list text[];
    num_pages smallint DEFAULT 0;
    start_page smallint;
    end_page smallint;
BEGIN
    SELECT
        trim(BOTH ' ' FROM pr) INTO trimmed_pr;
    IF trimmed_pr !~ '^([0-9]+(-[0-9]+)?)(,([0-9]+(-[0-9]+)?))*$' THEN
        RAISE 'Invalid page range';
    END IF;
    FOREACH a_range IN ARRAY regexp_split_to_array(trimmed_pr, ',')
    LOOP
        SELECT
            regexp_split_to_array(a_range, '-') INTO range_list;
        IF array_length(range_list, 1) > 1 THEN
            SELECT
                to_number(range_list[1], '999') INTO start_page;
            SELECT
                to_number(range_list[2], '999') INTO end_page;
            IF start_page >= end_page THEN
                RAISE 'Invalid page range';
            END IF;
            num_pages := num_pages + end_page - start_page + 1;
        ELSE
            num_pages := num_pages + 1;
        END IF;
    END LOOP;
    RETURN num_pages;
END;
$$
LANGUAGE plpgsql
STRICT;

CREATE OR REPLACE FUNCTION public.calc_job_price (pc print_config)
    RETURNS money
    AS $$
DECLARE
    num_pages smallint;
    cpp money;
BEGIN
    IF pc.page_range IS NOT NULL THEN
        SELECT
            public.parse_page_range (pc.page_range) INTO num_pages;
    ELSE
        num_pages := pc.num_pages;
    END IF;
    IF pc.color = 'BLACK' THEN
        cpp := 0.08;
    ELSE
        cpp := 0.11;
    END IF;
    RETURN num_pages * pc.num_copies * cpp;
END;
$$
LANGUAGE plpgsql
STRICT;

-- -- REVOKE ALL ON FUNCTION public.register_player FROM authuser;
-- CREATE OR REPLACE FUNCTION public.join_game (game_id uuid)
--     RETURNS public.game
--     AS $$
-- DECLARE
--     igame public.game;
--     player_id uuid;
-- BEGIN
--     IF game_id IS NOT NULL THEN
--         SELECT
--             * INTO igame
--         FROM
--             public.game
--         WHERE
--             id = game_id;
--         RETURN igame;
--     END IF;
--     SELECT
--         * INTO igame
--     FROM
--         public.game
--     WHERE
--         id = (
--             SELECT
--                 gp.game_id
--             FROM
--                 public.game_player AS gp
--             GROUP BY
--                 gp.game_id
--             HAVING
--                 count(*) < 3
--                 AND gp.game_id IN (
--                     SELECT
--                         id
--                     FROM
--                         public.game
--                     WHERE
--                         status = 'waiting')
--                 ORDER BY
--                     random()
--                 LIMIT 1);
--     SELECT
--         id INTO player_id
--     FROM
--         public.current_player ();
--     IF igame IS NOT NULL THEN
--         INSERT INTO public.game_player (game_id, player_id)
--             VALUES (igame.id, player_id);
--         PERFORM
--             graphile_worker.add_job ('create_player_subscription', json_build_object('game_id', igame.id, 'player_id', player_id));
--         RETURN igame;
--     END IF;
--     INSERT INTO public.game DEFAULT
--         VALUES
--         RETURNING
--             * INTO igame;
--     INSERT INTO public.game_player (game_id, player_id)
--         VALUES (igame.id, (
--                 SELECT
--                     id
--                 FROM
--                     public.current_player ()));
--     PERFORM
--         graphile_worker.add_job ('create_game_topic', json_build_object('game_id', igame.id, 'player_id', player_id));
--     RETURN igame;
-- END;
-- $$
-- LANGUAGE plpgsql
-- SECURITY DEFINER;
-- COMMENT ON FUNCTION public.join_game (uuid) IS 'Player joins a game room';
-- GRANT EXECUTE ON FUNCTION public.join_game (uuid) TO authuser;
