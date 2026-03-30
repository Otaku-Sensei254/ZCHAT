defmodule Vibeflow.Utils.Mentions do
    @doc """
    Finds a username when mention in a post or comment and returns as unique list
    """

    def extract(text) when is_binary(text) do
      Regex.scan(~r/@([a-zA-Z0-9_]+)/, text)
      |> Enum.map(fn [_, username] -> String.downcase(username) end)
      |> Enum.uniq()
    end
end
