defmodule Vibeflow.Repo.Migrations.AddSharedWaveIdToMessages do
  use Ecto.Migration

  def up do
    unless column_exists?(:messages, :shared_wave_id) do
      alter table(:messages) do
        add :shared_wave_id, references(:waves, on_delete: :nilify_all)
      end
    end

    unless index_exists?(:messages, [:shared_wave_id]) do
      create index(:messages, [:shared_wave_id])
    end
  end

  def down do
    if column_exists?(:messages, :shared_wave_id) do
      alter table(:messages) do
        remove :shared_wave_id
      end
    end
  end

  defp column_exists?(table, column) do
    table = Atom.to_string(table)
    column = Atom.to_string(column)

    case repo().query("""
      SELECT 1 FROM information_schema.columns
      WHERE table_name = $1 AND column_name = $2
    """, [table, column]) do
      {:ok, %{rows: []}} -> false
      {:ok, %{rows: _}} -> true
      _ -> false
    end
  end

  defp index_exists?(table, columns) when is_list(columns) do
    table = Atom.to_string(table)
    # Build a pattern to match index name
    index_pattern = "#{table}_#{Enum.join(columns, "_")}_index"

    case repo().query("""
      SELECT 1 FROM pg_indexes
      WHERE tablename = $1 AND indexname LIKE $2
    """, [table, "%#{index_pattern}%"]) do
      {:ok, %{rows: []}} -> false
      {:ok, %{rows: _}} -> true
      _ -> false
    end
  end
end
