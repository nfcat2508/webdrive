defmodule Webdrive.UploadTest do
  use Webdrive.DataCase, async: false

  import Webdrive.FilesFixtures

  alias Ecto.Changeset
  alias Webdrive.Files.Upload

  describe "validation:" do
    for field <- [:name, :hash, :owner] do
      test "#{field} must not be blank" do
        upload = prepare_upload_struct()
        field = unquote(field)

        assert %Changeset{errors: [_]} = Upload.changeset(upload, %{field => nil})
        assert %Changeset{errors: [_]} = Upload.changeset(upload, %{field => ""})
        assert %Changeset{errors: [_]} = Upload.changeset(upload, %{field => " "})
      end
    end

    test "size must not be nil" do
      assert %Changeset{errors: [_]} = Upload.changeset(prepare_upload_struct(), %{size: nil})
    end

    test "encrypted must not be nil" do
      assert %Changeset{errors: [_]} =
               Upload.changeset(prepare_upload_struct(), %{encrypted: nil})
    end

    test "content_type is optional" do
      content_type_nil = Upload.changeset(prepare_upload_struct(), %{content_type: nil})
      assert content_type_nil.valid?

      content_type_empty = Upload.changeset(prepare_upload_struct(), %{content_type: ""})
      assert content_type_empty.valid?
    end

    test "content_type max length is 100" do
      content_type_100 =
        Upload.changeset(prepare_upload_struct(), %{content_type: String.duplicate("1", 100)})

      assert content_type_100.valid?

      content_type_101 =
        Upload.changeset(prepare_upload_struct(), %{content_type: String.duplicate("1", 101)})

      refute content_type_101.valid?
    end

    test "name max length is 100" do
      name_100 =
        Upload.changeset(prepare_upload_struct(), %{name: String.duplicate("1", 100)})

      assert name_100.valid?

      name_101 =
        Upload.changeset(prepare_upload_struct(), %{name: String.duplicate("1", 101)})

      refute name_101.valid?
    end
  end

  test "changeset/2 sanitizes given content-type" do
    expectations = %{
      "application/epub+zip" => "application/epub+zip",
      "aB1ö.-+/" => "aB1ö.-+/",
      "\\=&$" => "____"
    }

    Enum.each(expectations, fn {given, expected} ->
      prepare_upload_struct()
      |> Upload.changeset(%{content_type: given})
      |> Changeset.fetch_change!(:content_type)
      |> (&assert(&1 == expected)).()
    end)
  end

  test "changeset/2 sanitizes given filename" do
    expectations = %{
      "aBßäæ1-_#.txt" => "aBßäæ1-_#.txt",
      "ab?\\&%$()/cd" => "ab________cd"
    }

    Enum.each(expectations, fn {given, expected} ->
      prepare_upload_struct()
      |> Upload.changeset(%{name: given})
      |> Changeset.fetch_change!(:name)
      |> (&assert(&1 == expected)).()
    end)
  end

  test "sha512/1 produces a base16 encoded lowercase string" do
    sha_sum = Upload.sha512(["cat"])

    allowed_chars = "0123456789abcdef" |> String.codepoints()

    assert all?(sha_sum, allowed_chars)
    assert String.length(sha_sum) == 128
    assert sha_sum == Upload.sha512(["cat"])
    assert sha_sum != Upload.sha512(["meow"])
  end

  test "upload_directory is defined in config 'uploads_directory'" do
    config_value = Application.get_env(:webdrive, :uploads_directory)

    assert Upload.upload_directory() == config_value
  end

  test "local_path concatenates upload_directory, ID and filename" do
    actual = Upload.local_path(17, "my_filename")

    assert actual == "#{Upload.upload_directory()}/17-my_filename"
  end

  test "find_local_file/1 finds the file in uploads_directory starting with the given ID" do
    filename1 = "#{Upload.upload_directory()}/17-my_filename" |> file_with_content()
    filename2 = "#{Upload.upload_directory()}/23-my_cats" |> file_with_content()

    assert Upload.find_local_file(17) == filename1
    assert Upload.find_local_file(23) == filename2
  end

  test "find_local_file/1 finds the first file in uploads_directory starting with the given ID" do
    filename1 = "#{Upload.upload_directory()}/17-my_filename" |> file_with_content()
    file_with_content("#{Upload.upload_directory()}/18-my_cats")

    assert Upload.find_local_file(17) == filename1
  end

  test "find_local_file/1 returns nil, if no file in upload_directory starts with the given ID" do
    file_with_content("#{Upload.upload_directory()}/17-my_filename")

    assert Upload.find_local_file(23) == nil
  end

  defp all?(string, allowed_chars) do
    string
    |> String.codepoints()
    |> Enum.all?(&(&1 in allowed_chars))
  end
end
