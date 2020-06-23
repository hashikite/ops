def system!(*args)
  system(*args) or fail("Command exited with status #{$?.exitstatus}: #{args.join(" ")}")
end

TERRAFORM_PLAN_NAME = ".terraform/terraform.tfplan".freeze

namespace :buildkite do
  namespace :terraform do
    task :setup do
      puts "--- :gear: Configuring terraform"

      Rake::Task["terraform:setup"].invoke
    end

    desc "Runs terraform:validate"
    task :validate => :setup do
      puts "+++ :mag: Validating terraform"

      Rake::Task["terraform:validate"].invoke
    end

    desc "Run terraform:plan and upload plan and new blocked pipeline step to apply if neccessary"
    task :plan => [:setup] do
      puts "+++ :thinking_face: Terraform plan"

      Rake::Task["terraform:plan"].invoke

      if File.exists?(TERRAFORM_PLAN_NAME)
        puts "--- :construction_worker: There are changes to apply"

        puts "Uploading plan artifact"
        system! "buildkite-agent", "artifact", "upload", TERRAFORM_PLAN_NAME

        puts "Upload apply step"
        IO.popen(["buildkite-agent", "pipeline", "upload"], "w") do |io|
          io.write <<~STEPS
            ---
            steps:
            - block: ":rocket: Apply to production"
              key: terraform:apply:confirm
              branches: master
            - label: ":terraform: :running: Terraform Apply"
              key: terraform:apply
              depends_on: terraform:apply:confirm
              branches: master
              command:
                rake buildkite:terraform:apply
              agents:
                queue: ops
          STEPS
        end
        fail unless $?.success?
      else
        puts "--- :bowtie: There are no changes"
      end
    end

    desc "Download terraform plan artifact and run terraform:apply"
    task :apply => [:setup] do
      puts "--- :buildkite: Downloading plan artifact"

      system! "buildkite-agent", "artifact", "download", TERRAFORM_PLAN_NAME, TERRAFORM_PLAN_NAME

      puts "+++ :running: Terraform apply"

      Rake::Task["terraform:apply"].invoke
    end
  end
end

namespace :terraform do
  desc "Setup terraform remote state"
  task :setup do
    puts "Configure remote state"
    system! "terraform", "init"
  end

  desc "Validate terraform syntax"
  task :validate do
    system! "terraform", "validate"
  end

  desc "Plan terraform change"
  task :plan do
    system "terraform", "plan",
      "-out=#{TERRAFORM_PLAN_NAME}",
      "-detailed-exitcode"

    # -detailed-exitcode means we can decide what to do with the exit status
    case $?.exitstatus
    when 0 # Success, no changes
      File.unlink(TERRAFORM_PLAN_NAME) if File.exists?(TERRAFORM_PLAN_NAME)
    when 2 # Success, changes
      # Build an annotation for the maintainer:
      system "buildkite-agent", "annotate", "--style", "warning", <<~MARKDOWN
        Terraform determines the following changes need to be made:
        ```term
        #{`terraform show #{TERRAFORM_PLAN_NAME}`}
        ```
      MARKDOWN

      # Leave the plan, we may want it
    else # 1 is error, others are weird
      fail "Terraform plan exited with status: #{$?.exitstatus}"
    end
  end

  desc "Apply terraform change"
  task :apply do
    system! "terraform", "apply",
      "-input=false",
      TERRAFORM_PLAN_NAME
  end
end
