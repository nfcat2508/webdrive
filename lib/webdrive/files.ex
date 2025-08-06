defmodule Webdrive.Files do
  @moduledoc """
  The Files context.
  """

  import Ecto.Query, only: [from: 2]
  alias Ecto.Changeset
  alias Webdrive.Files.{FileSharing, FileSharingRequest, Upload, UploadRequest}
  alias Webdrive.Repo

  @doc """
  Convertes a given byte size into a human readable size string.

  ## Examples

      iex> human_readable_size(750)
      "750 B"
      
      iex> human_readable_size(1750)
      "1 KB"

      iex> human_readable_size(2543750)
      "2 MB"
  """
  def human_readable_size(bytes) when bytes < 1000, do: "#{bytes} B"

  def human_readable_size(bytes) when bytes >= 1_000_000,
    do: "#{Integer.floor_div(bytes, 1_000_000)} MB"

  def human_readable_size(bytes), do: "#{Integer.floor_div(bytes, 1000)} KB"

  @doc """
  Returns the list of uploads for a given sharing_id or owner.

  ## Examples

      iex> available_uploads(sharing_id, owner_id)
      [%Upload{}, ...]

  """
  def available_uploads(nil, owner_id), do: list_uploads_by_owner(owner_id)
  def available_uploads(sharing_id, _), do: list_uploads_by_sharing_id(sharing_id)

  @doc """
  Creates an upload entry and a corresponding file in file system..

  ## Examples

      iex> create_upload_from_params(upload_params, owner_id)
      %Upload{}

  """
  def create_upload_from_params(
        %{
          filename: filename,
          path: tmp_path,
          content_type: content_type,
          encrypted: encrypted
        },
        owner_id
      ) do
    Repo.transaction(fn ->
      with {:ok, %File.Stat{size: size}} <- File.stat(tmp_path),
           {:ok, upload} <-
             %Upload{}
             |> Upload.changeset(%{
               name: filename,
               content_type: content_type,
               hash: content_hash(tmp_path),
               size: size,
               owner: owner_id,
               encrypted: encrypted
             })
             |> Repo.insert(),
           :ok <-
             File.cp(
               tmp_path,
               Upload.local_path(upload.id, upload.name)
             ) do
        upload
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp content_hash(filepath) do
    filepath
    |> File.stream!([], 2048)
    |> Upload.sha512()
  end

  defp list_uploads_by_owner(owner_id) do
    from(u in Upload,
      where: u.owner == ^owner_id
    )
    |> Repo.all()
    |> Repo.preload(:sharing)
  end

  @doc """
  Returns file path and name for a given upload ID if authorized for given sharing_id or owner_id.

  ## Examples

      iex> get_upload(id, sharing_id, owner_id)
      {"/tmp/files/tmp1871872.txt", "my_temp_file.txt"}

  """
  def get_upload(id, sharing_id, owner_id) do
    with [] <- UploadRequest.changeset(%{id: id}).errors,
         uploads <- available_uploads(sharing_id, owner_id),
         upload = %Upload{} <- Enum.find(uploads, fn upload -> "#{upload.id}" == id end),
         local_path <- Upload.local_path(upload.id, upload.name),
         true <- File.exists?(local_path) do
      {local_path, upload.name}
    else
      false ->
        delete_or_error(id, owner_id)
        :error

      _ ->
        {:sus, "access not allowed"}
    end
  end

  defp list_uploads_by_sharing_id(sharing_id) do
    from(u in Upload,
      join: s in FileSharing,
      on: s.upload_id == u.id,
      where: s.identifier == ^sharing_id
    )
    |> Repo.all()
  end

  @doc """
  Deletes an upload entry and the corresponding file in file system..

  ## Examples

      iex> delete_upload(id, owner_id)
      %Upload{}

  """
  def delete_upload(id, owner_id) do
    with [] <- UploadRequest.changeset(%{id: id}).errors,
         {_, _} <- delete_or_error(id, owner_id) do
      id
      |> Upload.find_local_file()
      |> delete_file()
    else
      _ -> :error
    end
  end

  defp delete_or_error(id, owner_id) do
    result = Repo.delete_all(from(x in Upload, where: x.id == ^id and x.owner == ^owner_id))

    case result do
      {0, _} -> :error
      result -> result
    end
  end

  defp delete_file(nil), do: :ok

  defp delete_file(path), do: File.rm!(path)

  @doc """
  Gets a single file_sharing.

  Returns nil if the combination of ID and secret is invalid.

  ## Examples

      iex> get_sharing_by_id_and_secret!(some_existing_id, valid_secret)
      %FileSharing{}

      iex> get_file_sharing!(non_existing_id, secret)
      nil
  """
  def get_sharing_by_id_and_secret(id, secret) do
    with true <- FileSharingRequest.changeset(%{secret: secret, id: id}).valid?,
         decoded_id when is_binary(decoded_id) <- FileSharing.decode_identifier(id),
         sharing when sharing != nil <- Repo.get_by(FileSharing, identifier: decoded_id),
         true <- FileSharing.valid_secret?(sharing, secret) do
      Repo.preload(sharing, :upload)
    else
      _ -> nil
    end
  end

  @doc """
  Creates a file_sharing.

  ## Examples

      iex> create_file_sharing(%{field: value}, owner_id)
      {:ok, %FileSharing{}}

      iex> create_file_sharing(%{field: bad_value}, owner_id)
      {:error, %Ecto.Changeset{}}

  """
  def create_file_sharing(attrs, owner_id) do
    with changeset = %Changeset{errors: []} <-
           FileSharing.changeset(%FileSharing{owner: owner_id}, attrs),
         file when file != nil <- file_by_owner(changeset, owner_id) do
      Repo.insert(changeset)
    else
      _ -> {:error, "provided data not valid"}
    end
  end

  defp file_by_owner(file_sharing_changeset, owner_id) do
    upload_id = Changeset.fetch_change!(file_sharing_changeset, :upload_id)
    Repo.get_by(Upload, id: upload_id, owner: owner_id)
  end

  @doc """
  Deletes a file_sharing.

  ## Examples

      iex> delete_file_sharing(id, owner_id)
      :ok

      iex> delete_file_sharing(id, owner_id)
      :error

  """
  def delete_file_sharing(id, owner_id) do
    result =
      try do
        Repo.delete_all(from(x in FileSharing, where: x.id == ^id and x.owner == ^owner_id))
      rescue
        _ -> {0, "delete_file_sharing: Bad type provided for ID"}
      end

    case result do
      {0, _} -> :error
      _result -> :ok
    end
  end
end
