# Converts UploadedFiles into FileSets and attaches them to works.

class AttachFilesToWorkJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name
  attr_reader :ordered_members, :uploaded_files

  # @param [ActiveFedora::Base] work - the work object
  # @param [Array<Hyrax::UploadedFile>] uploaded_files - an array of files to attach
  def perform(work, uploaded_files, **work_attributes)
    @uploaded_files = uploaded_files
    validate_files!
    depositor = proxy_or_depositor(work)
    user = User.find_by_user_key(depositor)
    metadata = visibility_attributes(work_attributes)
    @ordered_members = work.ordered_members.to_a # Build array of ordered members
    process_uploaded_files(user, metadata, work)
    add_ordered_members(user, work)
  end

  private

    # The attributes used for visibility - sent as initial params to created FileSets.
    def visibility_attributes(attributes)
      attributes.slice(:visibility, :visibility_during_lease,
                       :visibility_after_lease, :lease_expiration_date,
                       :embargo_release_date, :visibility_during_embargo,
                       :visibility_after_embargo)
    end

    def validate_files!
      uploaded_files.each do |uploaded_file|
        next if uploaded_file.is_a? Hyrax::UploadedFile
        raise ArgumentError, "Hyrax::UploadedFile required, but #{uploaded_file.class} received: #{uploaded_file.inspect}"
      end
    end

    ##
    # A work with files attached by a proxy user will set the depositor as the intended user
    # that the proxy was depositing on behalf of. See tickets #2764, #2902.
    def proxy_or_depositor(work)
      work.on_behalf_of.blank? ? work.depositor : work.on_behalf_of
    end

    # Add all file_sets as ordered_members in a single action
    def add_ordered_members(user, work)
      actor = Hyrax::Actors::OrderedMembersActor.new(ordered_members)
      actor.attach_to_work(work)
      actor.run_callback(user)
    end

    def process_uploaded_files(user, metadata, work)
      work_permissions = work.permissions.map(&:to_hash)
      uploaded_files.each do |uploaded_file|
        actor = Hyrax::Actors::FileSetActor.new(FileSet.create, user)
        actor.create_metadata(metadata)
        actor.create_content(uploaded_file)
        actor.attach_to_work(work)
        actor.file_set.permissions_attributes = work_permissions
        ordered_members << actor.file_set
        uploaded_file.update(file_set_uri: actor.file_set.uri)
      end
    end
end
