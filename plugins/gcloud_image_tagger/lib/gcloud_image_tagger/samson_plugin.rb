# frozen_string_literal: true
require 'aws-sdk-core'

module SamsonGcloudImageTagger
  class Engine < Rails::Engine
    class << self
      # Note: not tagging builds from different project since that would be confusing ...
      # ideally do not tag any builds for projects that use shared builds ... but that is hard to know atm
      def tag(deploy)
        return unless ENV["DOCKER_FEATURE"]
        return unless deploy.succeeded?
        return unless builds = deploy.project.builds.
          where(git_sha: deploy.job.commit).where.not(docker_repo_digest: nil).to_a.presence

        builds.each do |build|
          digest = build.docker_repo_digest
          next unless digest =~ /(^|\/|\.)gcr.io\// # gcr.io or https://gcr.io or region like asia.gcr.io
          base = digest.split('@').first
          tag = deploy.stage.permalink
          command = ["gcloud", *container_in_beta, "container", "images", "add-tag", digest, "#{base}:#{tag}", "--quiet"]
          success, output = Samson::CommandExecutor.execute(*command, timeout: 10)
          deploy.job.append_output! "Tagging GCR image:\n#{command.join(" ")}\n#{output}\n#{success ? "SUCCESS" : "FAILED"}\n"
        end
      end

      private

      def container_in_beta
        @@container_in_beta ||= begin
          beta = Samson::CommandExecutor.execute("gcloud", "--version", timeout: 10).last.match?(/Google Cloud SDK 14\d\./)
          beta ? ["beta"] : []
        end
      end
    end
  end
end

Samson::Hooks.callback :after_deploy do |deploy, _|
  SamsonGcloudImageTagger::Engine.tag(deploy)
end
