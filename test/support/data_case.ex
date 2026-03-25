defmodule Vibeflow.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Vibeflow.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Vibeflow.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Vibeflow.DataCase
    end
  end

  setup tags do
    Vibeflow.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Vibeflow.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Vibeflow.Repo, {:shared, self()})
    end

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.checkin(Vibeflow.Repo) end)
    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
