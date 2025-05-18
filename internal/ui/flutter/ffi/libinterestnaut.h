// Generated libinterestnaut header
#ifndef LIBINTERESTNAUT_H
#define LIBINTERESTNAUT_H

#ifdef __cplusplus
extern "C" {
#endif

// Go exported functions will be declared here
void InterestnautInitialize();
void* InterestnautLoadModel(const char* path);
void InterestnautFreeModel(void* model);
void* InterestnautNewContext(void* model, int n_ctx);
void InterestnautFreeContext(void* ctx);
char* InterestnautGenerate(const char* model_path, const char* prompt, int max_tokens);
void InterestnautFreeString(char* str);

#ifdef __cplusplus
}
#endif

#endif // LIBINTERESTNAUT_H
