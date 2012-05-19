REBAR=./rebar

all:
	@$(REBAR) get-deps compile

edoc:
	@$(REBAR) doc

clean:
	@$(REBAR) clean

test: clean all build_test
	@erl -noshell -pa test -pa ebin -pa deps/*/ebin -s erldrop start_deps \
	-eval "eunit:test(erldrop_test, [verbose])" -s init stop

build_test:
	@erlc -o ebin test/*.erl

start:  all
	@erl -pa ebin -pa deps/*/ebin -s erldrop start_deps