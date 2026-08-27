defmodule Vibeflow.DriftsTest do
  use Vibeflow.DataCase, async: true

  alias Vibeflow.Drifts

  test "create_drift inserts a drift for the current user" do
    user = Vibeflow.AccountsFixtures.user_fixture()

    assert {:ok, drift} = Drifts.create_drift(user, %{note: "hello from drift test"})
    assert drift.note == "hello from drift test"
    assert drift.user_id == user.id
  end
end
