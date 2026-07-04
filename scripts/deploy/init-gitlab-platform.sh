#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Initialize GitLab REDI Platform via gitlab-rails
# Sprint 2 Stage 1 — shells only, no application code
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

if ! docker ps --format '{{.Names}}' | grep -q '^redi-gitlab$'; then
  log_error "redi-gitlab container not running"
  exit 1
fi

log_info "Initializing REDI group, projects, labels, milestones..."

docker exec redi-gitlab gitlab-rails runner '
projects = %w[
  redi-foundation redi-platform redi-runtime redi-infrastructure
  redi-knowledge redi-ai redi-lab redi-examples
]
labels = {
  "bug" => "#FF0000",
  "enhancement" => "#428BCA",
  "documentation" => "#F0AD4E",
  "infrastructure" => "#5CB85C",
  "platform" => "#5BC0DE",
  "security" => "#D9534F",
  "ai" => "#9B59B6",
  "knowledge" => "#2C3E50"
}
milestones = [
  ["Sprint 2", "Sprint 2 — Platform Foundation"],
  ["Sprint 3", "Sprint 3 — Knowledge Foundation"],
  ["Platform Foundation", "REDI Platform Foundation"],
  ["Knowledge Foundation", "REDI Knowledge Foundation"]
]

admin = User.find_by(username: "root")
org = Organizations::Organization.first
group = Group.find_by(path: "redi")
unless group
  group = Group.create!(name: "REDI", path: "redi", visibility_level: Gitlab::VisibilityLevel::PRIVATE, organization: org)
  group.add_owner(admin)
  puts "CREATED group REDI id=#{group.id}"
else
  puts "EXISTS group REDI id=#{group.id}"
end

projects.each do |path|
  full = "redi/#{path}"
  next if Project.find_by_full_path(full)
  Project.create!(
    name: path,
    path: path,
    namespace_id: group.id,
    visibility_level: Gitlab::VisibilityLevel::PRIVATE,
    creator: admin,
    organization: org
  )
  puts "CREATED project #{full}"
end

labels.each do |name, color|
  next if group.labels.find_by(title: name)
  group.labels.create!(title: name, color: color)
end
puts "LABELS ok"

milestones.each do |title, desc|
  next if group.milestones.find_by(title: title)
  group.milestones.create!(title: title, description: desc)
end
puts "MILESTONES ok"

template_project = Project.find_by_full_path("redi/redi-foundation")
if template_project
  wiki = template_project.wiki
  unless wiki.find_page("home")
    wiki.create_page("home", "# REDI Foundation\n\nPlatform wiki and shared templates for the REDI program.")
    puts "WIKI home created"
  end

  issue_tpl = <<~MD
    ---
    name: Bug Report
    about: Report a defect
    labels: bug
    ---
    ## Summary
    ## Steps to reproduce
    ## Expected behavior
    ## Actual behavior
  MD
  mr_tpl = <<~MD
    ## Summary
    ## Related issue
    ## Test plan
  MD

  template_project.create_repository unless template_project.repository_exists?
  branch = template_project.default_branch || "main"
  issue_path = ".gitlab/issue_templates/Bug.md"
  unless template_project.repository.blob_at(branch, issue_path)
    result = Files::CreateService.new(template_project, admin, {
      file_path: issue_path,
      branch_name: branch,
      commit_message: "Initialize issue template",
      file_content: issue_tpl
    }).execute
    puts(result[:status] == :success ? "FILE #{issue_path}" : "SKIP #{issue_path} (#{result[:message]})")
  end
  puts "NOTE: Add MR template and README via GitLab UI or follow-up commit (branch protection after init)"
end
puts "TEMPLATES ok"
'

log_info "GitLab platform initialization complete"
