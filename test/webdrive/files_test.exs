defmodule Webdrive.FilesTest do
  use Webdrive.DataCase

  import Webdrive.FilesFixtures

  alias Ecto.UUID
  alias Webdrive.Files

  describe "human_readable_size/1" do
    test "returns byte size if provided byte size < 1000" do
      assert Files.human_readable_size(999) == "999 B"
    end

    test "returns kilobyte size if provided 1000 <= byte size < 1000000" do
      assert Files.human_readable_size(1000) == "1 KB"
      assert Files.human_readable_size(999_999) == "999 KB"
      assert Files.human_readable_size(654_321) == "654 KB"
    end

    test "returns megabyte size if provided byte size >= 1000000" do
      assert Files.human_readable_size(1_000_000) == "1 MB"
      assert Files.human_readable_size(21_000_000) == "21 MB"
      assert Files.human_readable_size(817_000_000) == "817 MB"
    end
  end

  describe "uploads" do
    alias Webdrive.Files.Upload

    @describetag :tmp_dir

    test "available_uploads/2 returns uploads only for given owner" do
      given_owner = "cat1"
      upload1 = upload_fixture(%{owner: given_owner})
      upload_fixture(%{owner: "other_owner"})

      actual = Files.available_uploads(nil, given_owner)
      assert length(actual) == 1

      actual_upload = List.first(actual)
      assert_upload_fields(actual_upload, upload1)
      assert actual_upload.sharing == nil
    end

    test "available_uploads/2 returns all uploads not having a file-sharing for a given owner" do
      upload = upload_fixture()

      actual = Files.available_uploads(nil, upload.owner)
      assert length(actual) == 1

      actual_upload = List.first(actual)
      assert_upload_fields(actual_upload, upload)
      assert actual_upload.sharing == nil
    end

    test "available_uploads/2 returns all uploads including existing file-sharing for a given owner" do
      upload = upload_fixture()
      file_sharing = file_sharing_fixture(upload)

      actual = Files.available_uploads(nil, upload.owner)
      assert length(actual) == 1

      actual_upload = List.first(actual)
      assert_upload_fields(actual_upload, upload)
      assert actual_upload.sharing.id == file_sharing.id
    end

    test "available_uploads/2 returns all shared uploads for a given sharing_id" do
      upload = upload_fixture()
      file_sharing = file_sharing_fixture(upload)

      actual = Files.available_uploads(file_sharing.identifier, upload.owner)
      assert length(actual) == 1

      actual_upload = List.first(actual)
      assert_upload_fields(actual_upload, upload)
      # sharing should not be loaded
      assert %Ecto.Association.NotLoaded{} = actual_upload.sharing
    end

    test "get_upload/3 returns file path and name, if requested by owner" do
      upload = upload_fixture()
      path = Upload.local_path(upload.id, upload.name)
      File.write(path, "test")

      actual = Files.get_upload(upload.id, nil, upload.owner)

      assert actual == {path, upload.name}
    end

    test "get_upload/3 returns file path and name, if request authorized by sharing ID" do
      upload = upload_fixture()
      file_sharing = file_sharing_fixture(upload)
      path = Upload.local_path(upload.id, upload.name)
      File.write(path, "test")

      actual = Files.get_upload(upload.id, file_sharing.identifier, nil)

      assert actual == {path, upload.name}
    end

    test "get_upload/3 regards invalid id as suspicious" do
      upload = upload_fixture()
      path = Upload.local_path(upload.id, upload.name)
      File.write(path, "test")

      actual = Files.get_upload("invalid_uuid", nil, upload.owner)

      assert actual == {:sus, "access not allowed"}
    end

    test "get_upload/3 regards ID not accessbile by user as suspicious" do
      upload = upload_fixture()
      upload_other = upload_fixture(%{owner: "other_owner"})
      path = Upload.local_path(upload.id, upload.name)
      File.write(path, "test")

      actual = Files.get_upload(upload.id, nil, upload_other.owner)

      assert actual == {:sus, "access not allowed"}
    end

    # this happens only if meta data in database and actual files in upload folder are out of sync
    test "get_upload/3 removes item from repo, if local file does not exist anymore" do
      # given an upload for which no local file exist (anymore)
      upload = upload_fixture()

      # when such an item is requested
      actual = Files.get_upload(upload.id, nil, upload.owner)

      # then an error is returned
      assert actual == :error
      # and the item is deleted in repo
      assert Webdrive.Repo.all(Upload) == []
    end

    test "create_upload/2 with valid data creates an upload", %{tmp_dir: tmp_dir} do
      test_file = "#{tmp_dir}/create_upload_test.txt"
      test_file_content = "my cat wants that bird"
      owner = "Kitty"

      valid_attrs =
        file_with_content(test_file, test_file_content)
        |> prepare_upload_params(%{content_type: "text/plain", encrypted: true})

      assert {:ok, %Upload{} = upload} = Files.create_upload_from_params(valid_attrs, owner)
      assert upload.content_type == "text/plain"
      assert upload.hash == Upload.sha512(File.stream!(test_file, [], 2048))
      assert upload.name == "create_upload_test.txt"
      assert upload.owner == owner
      assert upload.size == String.length(test_file_content)
      assert upload.encrypted == true

      assert File.exists?(Upload.local_path(upload.id, upload.name))
    end

    test "create_upload/2 stores sanitized filename", %{tmp_dir: tmp_dir} do
      test_file = "#{tmp_dir}/create upload test.txt"
      test_file_content = "my cat wants that bird"
      owner = "Kitty"

      valid_attrs =
        test_file
        |> file_with_content(test_file_content)
        |> prepare_upload_params()

      {:ok, upload} = Files.create_upload_from_params(valid_attrs, owner)
      assert upload.name == "create_upload_test.txt"

      assert File.exists?(Upload.local_path(upload.id, upload.name))
    end

    test "create_upload/2 with invalid data returns error changeset", %{tmp_dir: tmp_dir} do
      test_file = "#{tmp_dir}/tmp_test.txt"
      owner = "kitty"

      invalid_attrs =
        file_with_content(test_file, "hi")
        |> prepare_upload_params()
        # blank filename is invalid
        |> Map.replace(:filename, " ")

      assert {:error, %Ecto.Changeset{}} = Files.create_upload_from_params(invalid_attrs, owner)

      assert File.ls!(Upload.upload_directory()) == [], "expected upload directory to be empty"
    end

    test "delete_upload/2 with valid ID deletes the corresponding local file" do
      # given
      upload = upload_fixture()

      local_filename =
        Upload.local_path(upload.id, upload.name)
        |> file_with_content()

      # when
      Files.delete_upload(upload.id, upload.owner)

      # then
      refute File.exists?(local_filename)
    end

    test "delete_upload/2 with valid ID deletes the corresponding record in repo" do
      # given
      given_owner = "cat1"
      upload1 = upload_fixture(%{owner: given_owner})
      Upload.local_path(upload1.id, upload1.name) |> file_with_content()
      upload2 = upload_fixture(%{owner: given_owner})

      # when
      actual = Files.delete_upload(upload1.id, upload1.owner)

      # then
      assert actual == :ok
      assert upload_ids_in_repo(given_owner) == [upload2.id]
    end

    test "delete_upload/2 returns error if file not owned by current user" do
      # given
      upload = upload_fixture(%{owner: "file_owner"})

      assert Files.delete_upload(upload.id, "other_user") == :error
    end

    test "delete_upload/2 with unknown ID returns :error" do
      # when
      actual = Files.delete_upload(UUID.generate(), "owner")

      # then
      assert actual == :error
    end

    test "delete_upload/2 with invalid ID type returns :error" do
      # when
      actual = Files.delete_upload(23, "owner")

      # then
      assert actual == :error
    end

    test "delete_upload/2 with ID not found in record does not delete the local file" do
      # given
      upload = upload_fixture()
      unknown_id_in_repo = UUID.generate()

      # even if there is a local file for the unknown ID, we don't delete (cleanup could be done by a separate process)
      local_filename =
        Upload.local_path(unknown_id_in_repo, upload.name)
        |> file_with_content()

      # when
      Files.delete_upload(unknown_id_in_repo, upload.owner)

      # then
      assert File.exists?(local_filename)
    end

    test "delete_upload/2 deletes record in repo even if local file does not exist" do
      # given
      upload = upload_fixture()

      # when
      actual = Files.delete_upload(upload.id, upload.owner)

      # then
      assert actual == :ok
      assert upload_ids_in_repo(upload.owner) == []
    end

    defp assert_upload_fields(actual, expected) do
      assert actual.content_type == expected.content_type
      assert actual.hash == expected.hash
      assert actual.name == expected.name
      assert actual.owner == expected.owner
      assert actual.size == expected.size
    end

    defp upload_ids_in_repo(owner), do: Files.available_uploads(nil, owner) |> Enum.map(& &1.id)
  end

  describe "file_sharings" do
    alias Webdrive.Files.FileSharing

    @invalid_attrs %{secret: nil}

    setup do
      [existing_upload: upload_fixture()]
    end

    test "get_sharing_by_id_and_secret/2 returns the file_sharing with given ID and secret", %{
      existing_upload: upload
    } do
      secret = "cats!_AT_n8!"
      file_sharing = file_sharing_fixture(%{upload_id: upload.id, secret: secret}, upload.owner)

      actual = Files.get_sharing_by_id_and_secret(file_sharing.identifier_user_param, secret)
      assert actual.id == file_sharing.id
      assert actual.identifier == file_sharing.identifier
      assert actual.secret == file_sharing.secret
      assert actual.upload == upload
    end

    test "get_sharing_by_id_and_secret/2 returns nil, if no valid ID provided" do
      invalid_id = "notBase64"
      secret = "cats!_AT_n8!"

      actual = Files.get_sharing_by_id_and_secret(invalid_id, secret)

      assert actual == nil
    end

    test "get_sharing_by_id_and_secret/2 returns nil, if provided ID is unknown", %{
      existing_upload: upload
    } do
      secret = "cats!_AT_n8!"
      file_sharing = file_sharing_fixture(%{upload_id: upload.id, secret: secret}, upload.owner)

      unknown_id =
        FileSharing.changeset(file_sharing, %{upload_id: UUID.generate(), secret: secret}).changes.identifier_user_param

      actual = Files.get_sharing_by_id_and_secret(unknown_id, secret)

      assert actual == nil
    end

    test "get_sharing_by_id_and_secret/2 returns nil, if provided secret is not correct", %{
      existing_upload: upload
    } do
      secret = "cats!_AT_n8!"
      file_sharing = file_sharing_fixture(%{upload_id: upload.id, secret: secret}, upload.owner)

      actual =
        Files.get_sharing_by_id_and_secret(file_sharing.identifier_user_param, "wrong_Secret!")

      assert actual == nil
    end

    test "create_file_sharing/2 with valid data creates a file_sharing", %{
      existing_upload: upload
    } do
      current_user = upload.owner
      valid_attrs = prepare_file_sharing_attrs(%{upload_id: upload.id})

      assert {:ok, %FileSharing{} = actual} = Files.create_file_sharing(valid_attrs, current_user)
      assert FileSharing.decode_identifier(actual.identifier_user_param) == actual.identifier
      assert FileSharing.valid_secret?(actual, valid_attrs.secret)
    end

    test "create_file_sharing/2 returns error if file not owned by current user", %{
      existing_upload: upload
    } do
      current_user = "not_owner_of_file"
      valid_attrs = prepare_file_sharing_attrs(%{upload_id: upload.id})

      assert {:error, _} = Files.create_file_sharing(valid_attrs, current_user)
    end

    test "create_file_sharing/2 with invalid data returns error" do
      current_user = "owner"
      assert {:error, _} = Files.create_file_sharing(@invalid_attrs, current_user)
    end

    test "create_file_sharing/2 without data returns error" do
      current_user = "owner"
      assert {:error, _} = Files.create_file_sharing(%{}, current_user)
    end

    test "create_file_sharing/2 without current user returns error", %{
      existing_upload: upload
    } do
      valid_attrs = prepare_file_sharing_attrs(%{upload_id: upload.id})
      current_user = nil

      {:error, _} = Files.create_file_sharing(valid_attrs, current_user)
    end

    test "delete_file_sharing/2 deletes the file_sharing", %{existing_upload: upload} do
      secret = "cats!_AT_n8!"
      user = upload.owner
      file_sharing = file_sharing_fixture(%{upload_id: upload.id, secret: secret}, user)

      assert Files.delete_file_sharing(file_sharing.id, user) == :ok

      assert Files.get_sharing_by_id_and_secret(file_sharing.identifier_user_param, secret) == nil
    end

    test "delete_file_sharing/2 returns error if file not owned by current user", %{
      existing_upload: upload
    } do
      secret = "cats!_AT_n8!"
      user = "not_the_owner"
      file_sharing = file_sharing_fixture(%{upload_id: upload.id, secret: secret}, upload.owner)

      assert Files.delete_file_sharing(file_sharing.id, user) == :error
    end

    test "delete_file_sharing/2 returns error if ID is unknown", %{existing_upload: upload} do
      user = upload.owner
      file_sharing_fixture(upload)

      assert Files.delete_file_sharing(UUID.generate(), user) == :error
    end

    test "delete_file_sharing/2 returns error if ID is of invalid type", %{
      existing_upload: upload
    } do
      user = upload.owner
      file_sharing_fixture(upload)

      assert Files.delete_file_sharing(99, user) == :error
    end

    test "delete_file_sharing/2 without current user returns error", %{
      existing_upload: upload
    } do
      user = nil
      file_sharing = file_sharing_fixture(upload)

      assert Files.delete_file_sharing(file_sharing.id, user) == :error
    end
  end
end
