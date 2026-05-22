#!/usr/bin/env ruby
# Add the TalkyLiveActivities widget extension target + Shared sources to the
# WalkieTalkie Xcode project. Idempotent — safe to run multiple times.

require 'xcodeproj'
require 'fileutils'

PROJECT_DIR = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(PROJECT_DIR, 'WalkieTalkie.xcodeproj')
APP_TARGET_NAME = 'WalkieTalkie'
WIDGET_TARGET_NAME = 'TalkyLiveActivities'
WIDGET_BUNDLE_ID = 'com.Andrea-Piani.WalkieTalkie.LiveActivities'
DEV_TEAM = 'ERAK83QBBM'
WIDGET_DEPLOYMENT = '16.2'

project = Xcodeproj::Project.open(PROJECT_PATH)
app_target = project.targets.find { |t| t.name == APP_TARGET_NAME }
abort "App target #{APP_TARGET_NAME} not found" unless app_target

# Remove an existing widget target if present so this script is idempotent.
existing = project.targets.find { |t| t.name == WIDGET_TARGET_NAME }
if existing
  puts "Removing existing widget target for clean re-add"
  # Remove any dependency on it from the app target
  app_target.dependencies.each do |d|
    d.remove_from_project if d.target == existing
  end
  # Remove embed phase entries pointing at the widget product
  app_target.copy_files_build_phases.each do |phase|
    phase.files.dup.each do |bf|
      if bf.file_ref == existing.product_reference
        phase.remove_build_file(bf)
      end
    end
  end
  existing.remove_from_project
end

# --- Create the widget target ---------------------------------------------
widget_target = project.new_target(
  :app_extension,
  WIDGET_TARGET_NAME,
  :ios,
  WIDGET_DEPLOYMENT,
  nil,
  :swift
)

# --- Build settings ---------------------------------------------------------
widget_target.build_configurations.each do |config|
  bs = config.build_settings
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = WIDGET_BUNDLE_ID
  bs['PRODUCT_NAME'] = '$(TARGET_NAME)'
  bs['INFOPLIST_FILE'] = "#{WIDGET_TARGET_NAME}/Info.plist"
  bs['GENERATE_INFOPLIST_FILE'] = 'NO'
  bs['DEVELOPMENT_TEAM'] = DEV_TEAM
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = WIDGET_DEPLOYMENT
  bs['SWIFT_VERSION'] = '5.0'
  bs['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  bs['MARKETING_VERSION'] = '2.0'
  bs['CURRENT_PROJECT_VERSION'] = '21'
  bs['TARGETED_DEVICE_FAMILY'] = '1,2'
  bs['SKIP_INSTALL'] = 'YES'
  bs['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
  bs['INFOPLIST_KEY_CFBundleDisplayName'] = 'Talky Live Activities'
  bs['INFOPLIST_KEY_NSHumanReadableCopyright'] = '© 2026 Andrea Piani'
  bs['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  bs['SWIFT_APPROACHABLE_CONCURRENCY'] = 'YES'
  bs['SWIFT_DEFAULT_ACTOR_ISOLATION'] = 'MainActor'
end

# --- Widget source files ----------------------------------------------------
# Use a traditional PBXGroup pointing at the on-disk folder TalkyLiveActivities/.
widget_group = project.main_group.find_subpath(WIDGET_TARGET_NAME, true)
widget_group.set_source_tree('<group>')
widget_group.set_path(WIDGET_TARGET_NAME)

# Strip any stale children before re-adding (idempotency).
widget_group.children.dup.each(&:remove_from_project)

widget_swift_files = [
  'TalkyLiveActivitiesBundle.swift',
  'RadioActivityWidget.swift',
  'WalkieActivityWidget.swift'
]
widget_swift_files.each do |fname|
  ref = widget_group.new_reference(fname)
  widget_target.add_file_references([ref])
end

# Add Info.plist as a non-source resource (referenced via INFOPLIST_FILE, not a build phase entry).
widget_group.new_reference('Info.plist')

# --- Shared files (added to BOTH targets) -----------------------------------
shared_group = project.main_group.find_subpath('Shared', true)
shared_group.set_source_tree('<group>')
shared_group.set_path('Shared')

# Remove stale Shared refs to keep idempotency.
shared_group.children.dup.each do |child|
  # Remove from any target's source phases first
  project.targets.each do |t|
    t.source_build_phase.files.dup.each do |bf|
      if bf.file_ref == child
        t.source_build_phase.remove_build_file(bf)
      end
    end
  end
  child.remove_from_project
end

shared_files = ['LiveActivityAttributes.swift', 'RadioActivityIntents.swift']
shared_files.each do |fname|
  ref = shared_group.new_reference(fname)
  app_target.add_file_references([ref])
  widget_target.add_file_references([ref])
end

# --- Widget as dependency + embedded extension in app target ----------------
app_target.add_dependency(widget_target)

# Look for an existing Embed Foundation Extensions phase
embed_phase = app_target.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
unless embed_phase
  embed_phase = app_target.new_copy_files_build_phase('Embed Foundation Extensions')
  embed_phase.symbol_dst_subfolder_spec = :plug_ins
end
# Clean any prior entries for this widget product
embed_phase.files.dup.each { |bf| embed_phase.remove_build_file(bf) }
build_file = embed_phase.add_file_reference(widget_target.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
puts "✅ Widget target '#{WIDGET_TARGET_NAME}' wired."
puts "   Bundle ID: #{WIDGET_BUNDLE_ID}"
puts "   iOS min: #{WIDGET_DEPLOYMENT}"
puts "   Shared sources: #{shared_files.join(', ')}"
