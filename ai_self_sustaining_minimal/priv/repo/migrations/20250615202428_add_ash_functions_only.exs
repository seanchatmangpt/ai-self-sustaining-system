defmodule AiSelfSustainingMinimal.Repo.Migrations.AddAshFunctionsOnly do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION ash_raise_error(json_data jsonb, type_signal ANYCOMPATIBLE)
    RETURNS ANYCOMPATIBLE AS $$
    BEGIN
        -- Raise an error with the provided JSON data.
        -- The JSON object is converted to text for inclusion in the error message.
        RAISE EXCEPTION 'ash_error: %', json_data::text;
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql
    STABLE
    SET search_path = '';
    """
  end

  def down do
    execute "DROP FUNCTION IF EXISTS ash_raise_error(jsonb, ANYCOMPATIBLE);"
  end
end