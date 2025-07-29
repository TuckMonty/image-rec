import React from "react";
import { Input, Button, Text, Box } from "@chakra-ui/react";

import { Spinner } from "@chakra-ui/react";

export default function ImageUploadInput({ id, onChange, file, multiple = true, accept = "image/*", buttonLabel = "Select Image", changeLabel = "Change Image", isLoading = false, ...props }) {
  return (
    <Box mb={2}>
      <Input
        id={id}
        type="file"
        accept={accept}
        multiple={multiple}
        display="none"
        onChange={onChange}
        {...props}
      />
      <Button
        as="label"
        htmlFor={id}
        colorScheme="teal"
        variant="outline"
        mb={2}
        cursor="pointer"
        isDisabled={isLoading}
      >
        {file ? changeLabel : buttonLabel}
      </Button>
      {isLoading && <Spinner size="sm" ml={2} color="teal.500" />}
      {file && (
        Array.isArray(file) ? (
          file.map((f, idx) => (
            <Text key={idx} ml={2} display="inline" fontSize="sm" color="gray.600">{f.name}</Text>
          ))
        ) : (
          <Text ml={2} display="inline" fontSize="sm" color="gray.600">{file.name}</Text>
        )
      )}
    </Box>
  );
}
