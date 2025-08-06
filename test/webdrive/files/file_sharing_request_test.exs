defmodule Webdrive.Files.FileSharingRequestTest do
  use Webdrive.DataCase, async: false

  import Webdrive.FilesFixtures

  alias Webdrive.Files.FileSharingRequest

  describe "validation:" do
    test "secret is required" do
      assert_field_required(:secret)
    end

    test "secret max length is 72" do
      attr = prepare_file_sharing_request_attrs()
      secret_72 = Map.put(attr, :secret, String.duplicate("1", 72))
      secret_73 = Map.put(attr, :secret, String.duplicate("1", 73))

      assert FileSharingRequest.changeset(secret_72).valid?
      refute FileSharingRequest.changeset(secret_73).valid?
    end

    test "identifier is required" do
      assert_field_required(:id)
    end

    test "identifier max length is 50" do
      attr = prepare_file_sharing_request_attrs()
      id_50 = Map.put(attr, :id, String.duplicate("1", 50))
      id_51 = Map.put(attr, :id, String.duplicate("1", 51))

      assert FileSharingRequest.changeset(id_50).valid?
      refute FileSharingRequest.changeset(id_51).valid?
    end

    test "identifier must be base64-url-encoded" do
      attr = prepare_file_sharing_request_attrs()
      id = Map.put(attr, :id, "abyzABYZ0189-_=")
      id_invalid_umlaut = Map.put(attr, :id, "abcö")
      id_invalid_special_char = Map.put(attr, :id, "abc+")

      assert FileSharingRequest.changeset(id).valid?

      assert [{:id, {"has invalid format", _}}] =
               FileSharingRequest.changeset(id_invalid_umlaut).errors

      refute FileSharingRequest.changeset(id_invalid_umlaut).valid?
      refute FileSharingRequest.changeset(id_invalid_special_char).valid?
    end

    defp assert_field_required(field) do
      attr = prepare_file_sharing_request_attrs()
      no = Map.put(attr, field, nil)
      empty = Map.put(attr, field, "")
      space_only = Map.put(attr, field, " ")

      assert [{^field, {"can't be blank", _}}] = FileSharingRequest.changeset(no).errors
      assert [{^field, {"can't be blank", _}}] = FileSharingRequest.changeset(empty).errors
      assert [{^field, {"can't be blank", _}}] = FileSharingRequest.changeset(space_only).errors
    end
  end
end
