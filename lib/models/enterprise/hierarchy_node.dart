import 'enterprise_role.dart';

/// Scope of a hierarchy node (platform / company / project / supplier).
enum RoleScopeType {
  platform('מערכת'),
  company('חברה'),
  project('פרויקט'),
  supplier('ספק');

  const RoleScopeType(this.label);
  final String label;
}

/// Capability summary for a role node.
class RoleCapabilitySummary {
  const RoleCapabilitySummary({
    required this.title,
    required this.capabilities,
  });

  final String title;
  final List<String> capabilities;
}

/// Single node in a permission hierarchy tree.
class HierarchyNode {
  const HierarchyNode({
    required this.title,
    required this.description,
    required this.scope,
    this.capabilities = const [],
    this.children = const [],
    this.canManageChildren = false,
    this.isEditableNow = false,
    this.futureRoleKey,
  });

  final String title;
  final String description;
  final RoleScopeType scope;
  final List<String> capabilities;
  final List<HierarchyNode> children;
  final bool canManageChildren;
  final bool isEditableNow;
  final EnterpriseRole? futureRoleKey;

  List<String> get childTitles =>
      children.map((c) => c.title).toList(growable: false);
}

/// Preset hierarchy tree for display.
class HierarchyTreePreset {
  const HierarchyTreePreset({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.root,
  });

  final String id;
  final String title;
  final String subtitle;
  final HierarchyNode root;
}
