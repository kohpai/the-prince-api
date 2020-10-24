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
SET balance = balance + amount
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
	SELECT trim(BOTH ' ' FROM pr)
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

CREATE OR REPLACE FUNCTION public.calc_job_price(print_config print_config_t)
	RETURNS money
AS
$$
DECLARE
	num_pages smallint;
	cpp       money;
BEGIN
	IF print_config.page_range IS NOT NULL THEN
		SELECT public.parse_page_range(print_config.page_range)
		INTO num_pages;
	ELSE
		num_pages := print_config.num_pages;
	END IF;
	IF print_config.color_mode = 'BLACK' THEN
		cpp := 0.50;
	ELSE
		cpp := 0.80;
	END IF;
	RETURN num_pages * print_config.num_copies * cpp;
END;
$$
	LANGUAGE plpgsql
	STRICT;

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
	SELECT public.calc_job_price(print_config)
	INTO price;
	IF price > c.balance THEN
		RAISE 'Balance is too low for this print job';
	END IF;
	INSERT INTO public.print_job (customer_id, filename, color_mode, page_range,
								  num_pages, num_copies, price)
	VALUES (c.id, filename, print_config.color_mode, print_config.page_range,
			print_config.num_pages, print_config.num_copies, price)
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

