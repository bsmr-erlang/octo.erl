-module(octo_pull_request_test).

%% octo_pull_request_test: Tests for the module `octo_pull_request`.

-include_lib("eunit/include/eunit.hrl").
-include("include/octo.hrl").

%% The tests

list_pull_requests_test() ->
  {ok, PullRequests} = octo:list_pull_requests("sdepold", "octo.erl", request_options()),
  PullRequest = find_test_pull_request_in_list(PullRequests),
  assert_pull_request(PullRequest).

read_pull_request_test() ->
  {ok, PullRequest} = octo:read_pull_request("sdepold", "octo.erl", 1, request_options()),
  assert_pull_request(PullRequest).

list_pull_request_commits_test() ->
  {ok, [Commit]} = octo:list_pull_request_commits("sdepold", "octo.erl", 1, request_options()),
  assert_commit(Commit).

list_pull_request_files_test() ->
  {ok, [File]} = octo:list_pull_request_files("sdepold", "octo.erl", 1, request_options()),
  assert_file(File).

is_pull_request_merged_test() ->
  ?assertEqual(
    octo:is_pull_request_merged("sdepold", "octo.erl", 1, request_options()),
    {ok, false}
  ),
  ?assertEqual(
    octo:is_pull_request_merged("sdepold", "octo.erl", 2, request_options()),
    {ok, true}
  ).

create_pull_request_test() ->
  {ok, PullRequest}        = create_test_pull_request(),
  {ok, _ClosedPullRequest} = close_pull_request(PullRequest),
  ?assertEqual(PullRequest#octo_pull_request.title, <<"Amazing new feature">>),
  ?assertEqual(PullRequest#octo_pull_request.body, <<"Please pull this in!">>).

update_pull_request_state_test() ->
  {ok, PullRequest}        = create_test_pull_request(),
  {ok, _ClosedPullRequest} = close_pull_request(PullRequest),
  {ok, AllPullRequests}    = octo:list_pull_requests("sdepold", "octo.erl-test", request_options()),
  ?assertEqual(AllPullRequests, []).

update_pull_request_title_test() ->
  {ok, PullRequest}        = create_test_pull_request(),
  {ok, UpdatedPullRequest} = update_pull_request(PullRequest, {{<<"title">>, <<"Something else">>}}),
  {ok, _ClosedPullRequest} = close_pull_request(PullRequest),
  ?assertEqual(UpdatedPullRequest#octo_pull_request.title, <<"Something else">>).

update_pull_request_body_test() ->
  {ok, PullRequest}        = create_test_pull_request(),
  {ok, UpdatedPullRequest} = update_pull_request(PullRequest, {{<<"body">>, <<"Noot">>}}),
  {ok, _ClosedPullRequest} = close_pull_request(PullRequest),
  ?assertEqual(UpdatedPullRequest#octo_pull_request.body, <<"Noot">>).

merge_pull_request_test_() ->
  {
    timeout, 60, fun () ->
      {ok, TestHead}       = octo:read_branch("sdepold", "octo.erl-test", "test/head", request_options()),
      {ok, TestBase}       = octo:read_branch("sdepold", "octo.erl-test", "test/base", request_options()),
      {ok, _TestHeadClone} = octo:create_branch("sdepold", "octo.erl-test", "test/head-clone", sha(TestHead), request_options()),
      {ok, _TestBaseClone} = octo:create_branch("sdepold", "octo.erl-test", "test/base-clone", sha(TestBase), request_options()),
      {ok, PullRequest}    = create_pull_request(<<"test/head-clone">>, <<"test/base-clone">>),
      {ok, false}          = octo:is_pull_request_merged("sdepold", "octo.erl-test", PullRequest#octo_pull_request.number, request_options()),
      {ok, _}              = octo:merge_pull_request("sdepold", "octo.erl-test", PullRequest#octo_pull_request.number, request_options()),
      {ok, true}           = octo:is_pull_request_merged("sdepold", "octo.erl-test", PullRequest#octo_pull_request.number, request_options()),
      {ok, _}              = octo:delete_branch("sdepold", "octo.erl-test", "test/head-clone", request_options()),
      {ok, _}              = octo:delete_branch("sdepold", "octo.erl-test", "test/base-clone", request_options())
    end
  }.

%% The test helpers

sha(Branch) ->
  {{<<"sha">>, Sha}, _, _} = Branch#octo_reference.object,
  binary_to_list(Sha).

find_test_pull_request_in_list([]) -> null;
find_test_pull_request_in_list([ PullRequest = #octo_pull_request{ title = <<"Test">> } | _]) -> PullRequest;
find_test_pull_request_in_list([ _ | Rest ]) -> find_test_pull_request_in_list(Rest).

assert_pull_request(PullRequest) ->
  ?assertEqual(PullRequest#octo_pull_request.id,         26701040),
  ?assertEqual(PullRequest#octo_pull_request.number,     1),
  ?assertEqual(PullRequest#octo_pull_request.html_url,   <<"https://github.com/sdepold/octo.erl/pull/1">>),
  ?assertEqual(PullRequest#octo_pull_request.title,      <<"Test">>),
  ?assertEqual(PullRequest#octo_pull_request.state,      <<"open">>),
  ?assertEqual(PullRequest#octo_pull_request.body,       <<"Do not close this PR as the tests are reading and checking it.">>),
  ?assertEqual(PullRequest#octo_pull_request.created_at, <<"2014-12-30T20:02:37Z">>),
  ?assertEqual(PullRequest#octo_pull_request.updated_at, <<"2015-07-31T04:35:33Z">>).

assert_commit(Commit) ->
  ?assertEqual(Commit#octo_commit.html_url, <<"https://github.com/sdepold/octo.erl/commit/b87ca4769260b778c6f4b6e5dadab546f5c89adc">>),
  ?assertEqual(Commit#octo_commit.sha,      <<"b87ca4769260b778c6f4b6e5dadab546f5c89adc">>).

assert_file(File) ->
  ?assertEqual(File#octo_file.sha,       <<"345e6aef713208c8d50cdea23b85e6ad831f0449">>),
  ?assertEqual(File#octo_file.filename,  <<"README.md">>),
  ?assertEqual(File#octo_file.status,    <<"modified">>),
  ?assertEqual(File#octo_file.additions, 1),
  ?assertEqual(File#octo_file.deletions, 12),
  ?assertEqual(File#octo_file.changes,   13),
  ?assertEqual(File#octo_file.blob_url,  <<"https://github.com/sdepold/octo.erl/blob/b87ca4769260b778c6f4b6e5dadab546f5c89adc/README.md">>).

request_options() ->
  AuthToken = os:getenv("AUTH_TOKEN"),
  case AuthToken of
    false -> [];
    _     -> [{auth, pat, AuthToken}]
  end.

update_pull_request(PullRequest, Payload) ->
  octo:update_pull_request(
    "sdepold", "octo.erl-test", PullRequest#octo_pull_request.number, Payload, request_options()
  ).

close_pull_request(PullRequest) ->
  update_pull_request(PullRequest, {{<<"state">>, <<"closed">>}}).

create_test_pull_request() ->
  create_pull_request(<<"test/head">>, <<"test/base">>).

create_pull_request(Head, Base) ->
  octo:create_pull_request("sdepold", "octo.erl-test", {
    {<<"title">>, <<"Amazing new feature">>},
    {<<"body">>, <<"Please pull this in!">>},
    {<<"head">>, Head},
    {<<"base">>, Base}
  }, request_options()).
