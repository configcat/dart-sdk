# Steps to deploy

## Preparation

1. Run tests
2. Increase the version in the `pubspec.yaml` file.
3. Increase the version in the `lib/src/constant.dart` file.
4. Add the description of the new version in `CHANGELOG.md`.
5. Commit & Push

## Publish

Use the **same version** for the git tag as in the properties file.

- Via git tag
    1. Create a new version tag.
       ```bash
       git tag [MAJOR].[MINOR].[PATCH]
       ```
       > Example: `git tag 2.5.5`
    2. Push the tag.
       ```bash
       git push origin --tags
       ```
- Via Github release

  Create a new [Github release](https://github.com/configcat/dart-sdk/releases) with a new version tag and release
  notes.

## Update import examples in local README.md

## Update code examples in ConfigCat Dashboard projects

`Steps to connect your application`

1. Update the `Manual` import example.

## Update import examples in Docs

## Update samples

Update and test sample apps with the new SDK version.