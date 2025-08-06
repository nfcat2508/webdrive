defmodule Webdrive.FilesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Webdrive.Files` context.
  """

  @dummy_hash String.duplicate("a", 128)

  alias Webdrive.Files.{FileSharing, Upload}

  @doc """
  Generate a upload.
  """
  def upload_fixture(attrs \\ %{}) do
    {:ok, upload} =
      attrs
      |> prepare_upload_changeset()
      |> Webdrive.Repo.insert()

    upload
  end

  @doc """
  Prepares an upload changeset.
  """
  def prepare_upload_changeset(attrs \\ %{}) do
    Upload.changeset(%Upload{}, prepare_upload(attrs))
  end

  @doc """
  Prepares an upload attribute map.
  """
  def prepare_upload(attrs \\ %{}) do
    Enum.into(attrs, %{
      content_type: "some content_type",
      hash: @dummy_hash,
      name: "some name",
      owner: "some owner",
      size: 42,
      encrypted: false
    })
  end

  def prepare_upload_struct(attrs \\ %{}) do
    struct(Upload, prepare_upload(attrs))
  end

  @doc """
  Prepares the upload params
  """
  def prepare_upload_params(path, attrs \\ %{}) do
    filename =
      path
      |> Path.split()
      |> List.last()

    Enum.into(attrs, %{
      content_type: "text/plain",
      filename: filename,
      path: path,
      encrypted: false
    })
  end

  @doc """
  Creates a file with the given filename and content
  """
  def file_with_content(filename, content \\ "1") do
    File.open(filename, [:write], fn file -> IO.binwrite(file, content) end)

    filename
  end

  @doc """
  Generate a file_sharing for a given upload or a given set of attributes
  """
  def file_sharing_fixture(%Upload{} = upload) do
    file_sharing_fixture(%{upload_id: upload.id}, upload.owner)
  end

  def file_sharing_fixture(attrs, user) do
    {:ok, file_sharing} =
      attrs
      |> prepare_file_sharing_attrs()
      |> Webdrive.Files.create_file_sharing(user)

    file_sharing
  end

  @doc """
  Prepares a FIleSharing.
  """
  def prepare_file_sharing(attrs \\ %{}) do
    target_attrs = prepare_file_sharing_attrs(attrs)

    struct(FileSharing, target_attrs)
    |> Map.put(:owner, "some_owner")
  end

  @doc """
  Prepares a map containing FileSharing attributes
  """
  def prepare_file_sharing_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      secret: "cats!_AT_n8!",
      upload_id: Ecto.UUID.generate()
    })
  end

  @doc """
  Prepares a map containing FileSharingRequest attributes
  """
  def prepare_file_sharing_request_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      secret: "cats!_AT_n8!",
      id: "sQ4_HYZKGiKuiBSWIJskan34yAoJmmP0DLPxrn4psPI"
    })
  end

  @doc """
  A valid secret for user input when creating a file sharing
  """
  def valid_secret do
    "cats!_AT_n8!"
  end
end
