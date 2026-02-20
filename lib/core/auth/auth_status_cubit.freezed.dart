// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_status_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AuthStatusState {
  AuthStatus get status => throw _privateConstructorUsedError;

  /// Create a copy of AuthStatusState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AuthStatusStateCopyWith<AuthStatusState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AuthStatusStateCopyWith<$Res> {
  factory $AuthStatusStateCopyWith(
    AuthStatusState value,
    $Res Function(AuthStatusState) then,
  ) = _$AuthStatusStateCopyWithImpl<$Res, AuthStatusState>;
  @useResult
  $Res call({AuthStatus status});
}

/// @nodoc
class _$AuthStatusStateCopyWithImpl<$Res, $Val extends AuthStatusState>
    implements $AuthStatusStateCopyWith<$Res> {
  _$AuthStatusStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AuthStatusState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? status = null}) {
    return _then(
      _value.copyWith(
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as AuthStatus,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AuthStatusStateImplCopyWith<$Res>
    implements $AuthStatusStateCopyWith<$Res> {
  factory _$$AuthStatusStateImplCopyWith(
    _$AuthStatusStateImpl value,
    $Res Function(_$AuthStatusStateImpl) then,
  ) = __$$AuthStatusStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({AuthStatus status});
}

/// @nodoc
class __$$AuthStatusStateImplCopyWithImpl<$Res>
    extends _$AuthStatusStateCopyWithImpl<$Res, _$AuthStatusStateImpl>
    implements _$$AuthStatusStateImplCopyWith<$Res> {
  __$$AuthStatusStateImplCopyWithImpl(
    _$AuthStatusStateImpl _value,
    $Res Function(_$AuthStatusStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuthStatusState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? status = null}) {
    return _then(
      _$AuthStatusStateImpl(
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as AuthStatus,
      ),
    );
  }
}

/// @nodoc

class _$AuthStatusStateImpl implements _AuthStatusState {
  const _$AuthStatusStateImpl({required this.status});

  @override
  final AuthStatus status;

  @override
  String toString() {
    return 'AuthStatusState(status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AuthStatusStateImpl &&
            (identical(other.status, status) || other.status == status));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status);

  /// Create a copy of AuthStatusState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AuthStatusStateImplCopyWith<_$AuthStatusStateImpl> get copyWith =>
      __$$AuthStatusStateImplCopyWithImpl<_$AuthStatusStateImpl>(
        this,
        _$identity,
      );
}

abstract class _AuthStatusState implements AuthStatusState {
  const factory _AuthStatusState({required final AuthStatus status}) =
      _$AuthStatusStateImpl;

  @override
  AuthStatus get status;

  /// Create a copy of AuthStatusState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AuthStatusStateImplCopyWith<_$AuthStatusStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
