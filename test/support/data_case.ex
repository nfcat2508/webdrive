defmodule Webdrive.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Webdrive.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias Webdrive.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Webdrive.DataCase
    end
  end

  setup tags do
    Webdrive.DataCase.setup_sandbox(tags)
    Webdrive.DataCase.setup_file_cleanup()
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Webdrive.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  Sets up the cleanup of files created during tests.
  """
  def setup_file_cleanup do
    on_exit(&cleanup_uploads_dir/0)
  end

  defp cleanup_uploads_dir do
    target_dir = Application.get_env(:webdrive, :uploads_directory)

    File.ls!(target_dir)
    |> Enum.each(&File.rm("#{target_dir}/#{&1}"))
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
