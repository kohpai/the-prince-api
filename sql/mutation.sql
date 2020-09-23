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

-- CREATE OR REPLACE FUNCTION public.current_player ()
--     RETURNS public.player
--     AS $$
--     SELECT
--         *
--     FROM
--         public.player
--     WHERE
--         firebase_uid = current_setting('jwt.claims.firebase_uid', TRUE)
-- $$
-- LANGUAGE SQL
-- STRICT
-- SECURITY DEFINER;
-- COMMENT ON FUNCTION public.current_player () IS 'Get current logged in player';
-- GRANT EXECUTE ON FUNCTION public.current_player () TO authuser;
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