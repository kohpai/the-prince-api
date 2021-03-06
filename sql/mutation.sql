CREATE OR REPLACE FUNCTION public.new_customer()
    RETURNS public.customer
AS
$$
INSERT INTO public.customer (id)
VALUES (current_setting('jwt.claims.firebase_uid', TRUE))
RETURNING *
$$
    LANGUAGE SQL
    STRICT
    SECURITY DEFINER;

COMMENT ON FUNCTION public.new_customer () IS E'@omit execute\nAdd a new customer from Firebase user';

CREATE OR REPLACE FUNCTION public.current_user()
    RETURNS public.customer
AS
$$
DECLARE
    c public.customer;
BEGIN
    SELECT *
    INTO c
    FROM public.customer
    WHERE id = current_setting('jwt.claims.firebase_uid', TRUE);
    IF c IS NULL THEN
        SELECT public.new_customer()
        INTO c;
    END IF;
    RETURN c;
END;
$$
    LANGUAGE plpgsql
    SECURITY DEFINER;

COMMENT ON FUNCTION public.current_user() IS 'Get current logged-in user';
GRANT EXECUTE ON FUNCTION public.current_user() TO authuser;

CREATE OR REPLACE FUNCTION public.top_up(order_id text, amount money)
    RETURNS public.customer
AS
$$
UPDATE
    public.customer
SET balance = balance + $2
WHERE id = current_setting('jwt.claims.firebase_uid', TRUE)
RETURNING *
$$
    LANGUAGE SQL
    STRICT
    SECURITY DEFINER;

COMMENT ON FUNCTION public.top_up (order_id text, amount money) IS 'Top up the customer''s balance';
GRANT EXECUTE ON FUNCTION public.top_up (order_id text, amount money) TO authuser;

CREATE OR REPLACE FUNCTION public.parse_page_range(page_range text)
    RETURNS smallint
AS
$$
DECLARE
    trimmed_pr text;
    a_range    text;
    range_list text[];
    num_pages  smallint DEFAULT 0;
    start_page smallint;
    end_page   smallint;
BEGIN
    SELECT trim(BOTH ' ' FROM $1)
    INTO trimmed_pr;
    IF trimmed_pr !~ '^([0-9]+(-[0-9]+)?)(,([0-9]+(-[0-9]+)?))*$' THEN
        RAISE 'Invalid page range';
    END IF;
    FOREACH a_range IN ARRAY regexp_split_to_array(trimmed_pr, ',')
        LOOP
            SELECT regexp_split_to_array(a_range, '-')
            INTO range_list;
            IF array_length(range_list, 1) > 1 THEN
                SELECT to_number(range_list[1], '999')
                INTO start_page;
                SELECT to_number(range_list[2], '999')
                INTO end_page;
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

COMMENT ON FUNCTION public.parse_page_range(page_range text) IS E'@omit execute';

CREATE OR REPLACE FUNCTION public.calc_job_price(print_config print_config_t)
    RETURNS money
AS
$$
DECLARE
    num_pages      smallint;
    printing_pages smallint;
    cpp            money;
    total          money;
BEGIN
    IF $1.page_range IS NOT NULL THEN
        SELECT public.parse_page_range($1.page_range)
        INTO num_pages;
    ELSE
        num_pages := $1.num_pages;
    END IF;
    IF $1.color_mode = 'BLACK' THEN
        SELECT current_setting('price_config.black_cpp', TRUE)::money INTO cpp;
    ELSE
        SELECT current_setting('price_config.color_cpp', TRUE)::money INTO cpp;
    END IF;

    SELECT num_pages * $1.num_copies INTO printing_pages;
    SELECT cpp * printing_pages INTO total;

    IF printing_pages >= 10 THEN
        RETURN total *
               (1 - current_setting('price_config.discount_ratio',
                                           TRUE)::real);
    ELSE
        RETURN total;
    END IF;
END;
$$
    LANGUAGE plpgsql
    STRICT;

COMMENT ON FUNCTION public.calc_job_price(print_config print_config_t) IS E'@omit execute';

CREATE OR REPLACE FUNCTION public.submit_print_job(filename text, print_config print_config_t)
    RETURNS public.print_job
AS
$$
DECLARE
    c     public.customer;
    price money;
    job   public.print_job;
BEGIN
    SELECT *
    INTO c
    FROM public.customer
    WHERE id = current_setting('jwt.claims.firebase_uid', TRUE);
    SELECT public.calc_job_price($2)
    INTO price;
    IF price > c.balance THEN
        RAISE 'Balance is too low for this print job';
    END IF;
    INSERT INTO public.print_job (customer_id, filename, color_mode, page_range,
                                  num_pages, num_copies, price)
    VALUES (c.id, filename, $2.color_mode, $2.page_range,
            $2.num_pages, $2.num_copies, price)
    RETURNING * INTO job;
    UPDATE
        public.customer
    SET balance = balance - price
    WHERE id = c.id;
    PERFORM
        graphile_worker.add_job('print_doc',
                                json_build_object('id', job.id, 'filepath',
                                                  format('upload/%s/%s', c.id, job.filename),
                                                  'printConfig',
                                                  json_build_object('colorMode',
                                                                    job.color_mode,
                                                                    'pageRange',
                                                                    job.page_range,
                                                                    'numCopies',
                                                                    job.num_copies)));
    RETURN job;
END;
$$
    LANGUAGE plpgsql
    STRICT
    SECURITY DEFINER;

COMMENT ON FUNCTION public.submit_print_job (filename text, print_config print_config_t) IS 'Submit a print job';

GRANT EXECUTE ON FUNCTION public.submit_print_job (filename text, print_config print_config_t) TO authuser;

