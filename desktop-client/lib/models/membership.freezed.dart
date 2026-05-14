// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'membership.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Membership {
  String get id;
  String get userId;
  String get projectId;
  MembershipRole get role;
  int get joinedAt;
  int get updatedAt;
  String? get invitedBy;

  /// Create a copy of Membership
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MembershipCopyWith<Membership> get copyWith =>
      _$MembershipCopyWithImpl<Membership>(this as Membership, _$identity);

  /// Serializes this Membership to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Membership &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.joinedAt, joinedAt) ||
                other.joinedAt == joinedAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.invitedBy, invitedBy) ||
                other.invitedBy == invitedBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, userId, projectId, role, joinedAt, updatedAt, invitedBy);

  @override
  String toString() {
    return 'Membership(id: $id, userId: $userId, projectId: $projectId, role: $role, joinedAt: $joinedAt, updatedAt: $updatedAt, invitedBy: $invitedBy)';
  }
}

/// @nodoc
abstract mixin class $MembershipCopyWith<$Res> {
  factory $MembershipCopyWith(
          Membership value, $Res Function(Membership) _then) =
      _$MembershipCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String userId,
      String projectId,
      MembershipRole role,
      int joinedAt,
      int updatedAt,
      String? invitedBy});
}

/// @nodoc
class _$MembershipCopyWithImpl<$Res> implements $MembershipCopyWith<$Res> {
  _$MembershipCopyWithImpl(this._self, this._then);

  final Membership _self;
  final $Res Function(Membership) _then;

  /// Create a copy of Membership
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? projectId = null,
    Object? role = null,
    Object? joinedAt = null,
    Object? updatedAt = null,
    Object? invitedBy = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      projectId: null == projectId
          ? _self.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as MembershipRole,
      joinedAt: null == joinedAt
          ? _self.joinedAt
          : joinedAt // ignore: cast_nullable_to_non_nullable
              as int,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as int,
      invitedBy: freezed == invitedBy
          ? _self.invitedBy
          : invitedBy // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [Membership].
extension MembershipPatterns on Membership {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_Membership value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Membership() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_Membership value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Membership():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_Membership value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Membership() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            String id,
            String userId,
            String projectId,
            MembershipRole role,
            int joinedAt,
            int updatedAt,
            String? invitedBy)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Membership() when $default != null:
        return $default(_that.id, _that.userId, _that.projectId, _that.role,
            _that.joinedAt, _that.updatedAt, _that.invitedBy);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String id, String userId, String projectId,
            MembershipRole role, int joinedAt, int updatedAt, String? invitedBy)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Membership():
        return $default(_that.id, _that.userId, _that.projectId, _that.role,
            _that.joinedAt, _that.updatedAt, _that.invitedBy);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            String id,
            String userId,
            String projectId,
            MembershipRole role,
            int joinedAt,
            int updatedAt,
            String? invitedBy)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Membership() when $default != null:
        return $default(_that.id, _that.userId, _that.projectId, _that.role,
            _that.joinedAt, _that.updatedAt, _that.invitedBy);
      case _:
        return null;
    }
  }
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _Membership implements Membership {
  const _Membership(
      {required this.id,
      required this.userId,
      required this.projectId,
      required this.role,
      required this.joinedAt,
      required this.updatedAt,
      this.invitedBy});
  factory _Membership.fromJson(Map<String, dynamic> json) =>
      _$MembershipFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String projectId;
  @override
  final MembershipRole role;
  @override
  final int joinedAt;
  @override
  final int updatedAt;
  @override
  final String? invitedBy;

  /// Create a copy of Membership
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MembershipCopyWith<_Membership> get copyWith =>
      __$MembershipCopyWithImpl<_Membership>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MembershipToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Membership &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.joinedAt, joinedAt) ||
                other.joinedAt == joinedAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.invitedBy, invitedBy) ||
                other.invitedBy == invitedBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, userId, projectId, role, joinedAt, updatedAt, invitedBy);

  @override
  String toString() {
    return 'Membership(id: $id, userId: $userId, projectId: $projectId, role: $role, joinedAt: $joinedAt, updatedAt: $updatedAt, invitedBy: $invitedBy)';
  }
}

/// @nodoc
abstract mixin class _$MembershipCopyWith<$Res>
    implements $MembershipCopyWith<$Res> {
  factory _$MembershipCopyWith(
          _Membership value, $Res Function(_Membership) _then) =
      __$MembershipCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String projectId,
      MembershipRole role,
      int joinedAt,
      int updatedAt,
      String? invitedBy});
}

/// @nodoc
class __$MembershipCopyWithImpl<$Res> implements _$MembershipCopyWith<$Res> {
  __$MembershipCopyWithImpl(this._self, this._then);

  final _Membership _self;
  final $Res Function(_Membership) _then;

  /// Create a copy of Membership
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? projectId = null,
    Object? role = null,
    Object? joinedAt = null,
    Object? updatedAt = null,
    Object? invitedBy = freezed,
  }) {
    return _then(_Membership(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      projectId: null == projectId
          ? _self.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as MembershipRole,
      joinedAt: null == joinedAt
          ? _self.joinedAt
          : joinedAt // ignore: cast_nullable_to_non_nullable
              as int,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as int,
      invitedBy: freezed == invitedBy
          ? _self.invitedBy
          : invitedBy // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
