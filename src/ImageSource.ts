/**
 * Local declaration of the codegen-reserved `ImageSource` type.
 *
 * RN codegen treats a prop typed `ImageSource` as the native image-source
 * primitive — but only when the type is *imported* (codegen name-matches
 * imported types; a locally-declared `type ImageSource = …` gets resolved to a
 * plain object instead). RN re-exports this type only on newer versions, so we
 * declare it here and import it from the codegen spec to stay typecheck-safe
 * against this package's pinned RN while codegen still maps it to an image.
 */
export type ImageSource = Readonly<{
  uri?: string;
  width?: number;
  height?: number;
  scale?: number;
  bundle?: string;
}>;
